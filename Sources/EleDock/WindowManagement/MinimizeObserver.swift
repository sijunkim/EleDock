import AppKit
import ApplicationServices
import EleDockCore

/// 창 최소화·복원·소멸을 알린다.
final class MinimizeObserver {
    /// 관찰 중 생긴 일.
    enum Event {
        /// 창이 최소화됐다.
        case minimized(WindowEntry)
        /// 관찰을 시작할 때 이미 최소화돼 있던 창.
        case alreadyMinimized(WindowEntry)
        /// 창이 복원됐거나 사라졌다.
        case gone(ManagedWindow)
        /// 앱이 종료돼 관찰을 그만뒀다.
        case forgotten(pid_t)
    }

    /// 이벤트를 받는 곳.
    var onEvent: (Event) -> Void = { _ in }

    /// 알림 등록·창 목록 조회 timeout.
    private static let registrationTimeout: Float = 0.25
    /// 미룬 소멸 알림 등록을 다시 시도하기 전 기다리는 시간.
    private static let registrationRetryDelay: TimeInterval = 0.5

    private var observers: [pid_t: AXObserver] = [:]
    private var workspaceTokens: [NSObjectProtocol] = []
    private var windowTokens: [NSObjectProtocol] = []
    /// 소멸 알림 등록을 기다리는 창.
    private var deferred = DeferredRegistrations<AXUIElement, pid_t>(group: \.pid)
    /// 관찰 시작을 미룬 앱.
    private var deferredApps = DeferredRegistrations<NSRunningApplication, pid_t>(group: \.processIdentifier)
    private var retryTask: Task<Void, Never>?
    private var isRepeating = false

    private var refcon: UnsafeMutableRawPointer { Unmanaged.passUnretained(self).toOpaque() }

    func start() {
        for app in NSWorkspace.shared.runningApplications {
            observeOrRetry(app)
        }
        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didActivateApplicationNotification] {
            workspaceTokens.append(
                nc.addObserver(forName: name, object: nil, queue: .main) { note in
                    guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                        return
                    }
                    MainActor.assumeIsolated { self.observeOrDefer(app) }
                })
        }
        workspaceTokens.append(
            nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) {
                note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                    return
                }
                let pid = app.processIdentifier
                MainActor.assumeIsolated { self.forget(pid: pid) }
            })
        observeOwnWindows()
    }

    // 이 앱 창의 최소화·복원·닫기를 관찰한다.
    private func observeOwnWindows() {
        for window in NSApp.windows where window.isMiniaturized {
            onEvent(.alreadyMinimized(WindowEntry(pid: getpid(), window: .own(window))))
        }
        for name in [
            NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification,
            NSWindow.willCloseNotification,
        ] {
            let minimized = name == NSWindow.didMiniaturizeNotification
            windowTokens.append(
                NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { note in
                    let window = note.object as? NSWindow
                    MainActor.assumeIsolated {
                        guard let window else { return }
                        let entry = WindowEntry(pid: getpid(), window: .own(window))
                        self.onEvent(minimized ? .minimized(entry) : .gone(entry.window))
                    }
                })
        }
    }

    // 관찰을 모두 해제한다.
    func stop() {
        let nc = NSWorkspace.shared.notificationCenter
        workspaceTokens.forEach(nc.removeObserver)
        workspaceTokens = []
        windowTokens.forEach(NotificationCenter.default.removeObserver)
        windowTokens = []
        for observer in observers.values {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), observer.runLoopSource, .commonModes)
        }
        observers = [:]
        retryTask?.cancel()
        retryTask = nil
        deferred = DeferredRegistrations(group: \.pid)
        deferredApps = DeferredRegistrations(group: \.processIdentifier)
    }

    // 소멸 알림 등록을 미룬다.
    func beginRepeat() {
        isRepeating = true
    }

    func endRepeat() {
        isRepeating = false
        if !deferred.isEmpty || !deferredApps.isEmpty { scheduleRetry() }
    }

    // 앱 관찰을 시작하거나 미룬다.
    private func observeOrDefer(_ app: NSRunningApplication) {
        guard isRepeating else { return observeOrRetry(app) }
        deferApp(app)
    }

    // 앱 관찰을 시작한다.
    private func observeOrRetry(_ app: NSRunningApplication) {
        guard observe(app) == .busy else { return }
        deferApp(app)
        scheduleRetry()
    }

    private func deferApp(_ app: NSRunningApplication) {
        guard !deferredApps.pending.contains(where: { $0.processIdentifier == app.processIdentifier }) else { return }
        deferredApps.add(app)
    }

    private func observe(_ app: NSRunningApplication) -> RegistrationOutcome {
        let pid = app.processIdentifier
        guard app.activationPolicy == .regular, pid != getpid(), observers[pid] == nil else { return .registered }

        guard let observer = try? AXObserver.make(pid: pid, callback: axCallback) else { return .failed }
        let appElement = AXUIElement.application(pid: pid)
        let windows: [AXUIElement]
        do {
            windows = try appElement.withMessagingTimeout(Self.registrationTimeout) {
                () throws(AccessibilityError) -> [AXUIElement] in
                try observer.add(kAXWindowMiniaturizedNotification, for: appElement, refcon: refcon)
                try observer.add(kAXWindowDeminiaturizedNotification, for: appElement, refcon: refcon)
                do throws(AccessibilityError) {
                    return try appElement.attribute(kAXWindowsAttribute) as? [AXUIElement] ?? []
                } catch .cannotComplete {
                    throw .cannotComplete
                } catch {
                    return []
                }
            }
        } catch .cannotComplete {
            return .busy
        } catch {
            return .failed
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), observer.runLoopSource, .commonModes)
        observers[pid] = observer

        for window in windows where window.withMessagingTimeout(Self.registrationTimeout, { window.isMinimized }) {
            try? window.withMessagingTimeout(Self.registrationTimeout) { () throws(AccessibilityError) in
                try observer.add(kAXUIElementDestroyedNotification, for: window, refcon: refcon)
            }
            onEvent(.alreadyMinimized(WindowEntry(pid: pid, window: .ax(window))))
        }
        return .registered
    }

    private func forget(pid: pid_t) {
        if let observer = observers.removeValue(forKey: pid) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), observer.runLoopSource, .commonModes)
        }
        deferred.removeAll { $0.pid == pid }
        deferredApps.removeAll { $0.processIdentifier == pid }
        onEvent(.forgotten(pid))
    }

    fileprivate func handle(element: AXUIElement, notification: String) {
        switch notification {
        case kAXWindowMiniaturizedNotification:
            onEvent(.minimized(WindowEntry(pid: element.pid, window: .ax(element))))
            deferred.add(element)
            if !isRepeating { flushDeferred() }
        case kAXWindowDeminiaturizedNotification, kAXUIElementDestroyedNotification:
            deferred.remove(element)
            onEvent(.gone(.ax(element)))
        default:
            break
        }
    }

    // 미룬 소멸 알림을 등록한다.
    private func flushDeferred() {
        for window in deferred.flush(register: registerDestroyed) {
            onEvent(.gone(.ax(window)))
        }
        if !deferred.isEmpty || !deferredApps.isEmpty { scheduleRetry() }
    }

    private func scheduleRetry() {
        guard retryTask == nil else { return }
        retryTask = Task {
            try? await Task.sleep(for: .seconds(Self.registrationRetryDelay))
            guard !Task.isCancelled else { return }
            retryTask = nil
            guard !isRepeating else { return }
            _ = deferredApps.flush(register: observe)
            flushDeferred()
        }
    }

    private func registerDestroyed(_ window: AXUIElement) -> RegistrationOutcome {
        guard let observer = observers[window.pid] else { return .failed }
        do {
            try window.withMessagingTimeout(WindowTracker.callTimeout) { () throws(AccessibilityError) in
                try observer.add(kAXUIElementDestroyedNotification, for: window, refcon: refcon)
            }
            return .registered
        } catch .cannotComplete {
            return .busy
        } catch .invalidUIElement {
            return .gone
        } catch .other(.notificationAlreadyRegistered) {
            return .registered
        } catch {
            return .failed
        }
    }
}

// AX 알림 콜백.
private nonisolated func axCallback(
    _: AXObserver, element: AXUIElement, notification: CFString, refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let target = Unmanaged<MinimizeObserver>.fromOpaque(refcon).takeUnretainedValue()
    let name = notification as String
    nonisolated(unsafe) let element = element
    MainActor.assumeIsolated {
        target.handle(element: element, notification: name)
    }
}
