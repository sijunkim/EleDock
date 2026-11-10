import AppKit
import EleDockCore

/// 최소화 순서를 추적하고 창을 최소화·복원한다.
final class WindowTracker {
    /// 창 조작 AX 호출의 timeout.
    static let callTimeout: Float = 0.1

    private let settings: AppSettings
    private let observer = MinimizeObserver()
    private var stack = MinimizedStack<ManagedWindow>()

    /// 이번 동작에서 최소화할 남은 후보.
    private var minimizeQueue: MinimizeQueue<WindowEntry>?
    /// 마지막으로 최소화를 보낸 뒤 남은 후보.
    private var focusCandidates: MinimizeQueue<WindowEntry>?
    /// 복원에서 맨 위 창이 연속으로 막힌 횟수.
    private var restoreStall = Stall<ManagedWindow>()
    /// 보낸 복원의 확정 상태.
    private(set) var restores = WindowConfirmations(key: \.window, app: \.pid, minimized: false)
    /// 보낸 최소화의 확정 상태.
    private var minimizes = WindowConfirmations(key: \.window, app: \.pid, minimized: true)
    /// 진행 중인 반복 마무리.
    private var settleTask: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
        observer.onEvent = { [weak self] in self?.handle($0) }
    }

    /// 관찰을 시작한다.
    func start() {
        observer.start()
    }

    /// 관찰을 멈추고 스택을 비운다.
    func stop() {
        observer.stop()
        stack = MinimizedStack()
        minimizeQueue = nil
        focusCandidates = nil
        restoreStall.reset()
        settleTask?.cancel()
        settleTask = nil
        restores = WindowConfirmations(key: \.window, app: \.pid, minimized: false)
        minimizes = WindowConfirmations(key: \.window, app: \.pid, minimized: true)
    }

    private func handle(_ event: MinimizeObserver.Event) {
        switch event {
        case .minimized(let entry):
            minimizes.confirm(entry.window)
            stack.push(entry)
        case .alreadyMinimized(let entry): stack.insertAtBottom(entry)
        case .gone(let window):
            stack.remove(window)
            restores.confirm(window)
            minimizes.confirm(window)
        case .forgotten(let pid):
            stack.removeAll(pid: pid)
            restores.discard { $0.pid == pid }
            minimizes.discard { $0.pid == pid }
        }
    }

    var minimizedCount: Int { stack.count }

    // 메뉴에 보여 줄 최근 최소화 창 최대 limit 개.
    func minimizedItems(limit: Int) -> [(window: ManagedWindow, pid: pid_t, title: String)] {
        stack.recent(limit: limit).map { entry in
            let title = entry.window.title
            return (
                entry.window, entry.pid,
                title ?? NSRunningApplication(processIdentifier: entry.pid)?.localizedName ?? ""
            )
        }
    }

    // 메뉴에서 고른 창을 복원하고 앞으로 가져온다.
    func restore(window: ManagedWindow) {
        var taken = stack.take(window)
        guard taken != nil else { return }
        beginRepeat(.restore)
        _ = restoreFromStack(
            pop: {
                defer { taken = nil }
                return taken
            }, isWaiting: { _ in false })
        endRepeat()
    }

    // `action` 방향의 동작을 시작한다.
    func beginRepeat(_ action: Shortcut.Kind) {
        settleTask?.cancel()
        settleTask = nil
        restores.beginRepeat()
        if action == .restore {
            minimizes = WindowConfirmations(key: \.window, app: \.pid, minimized: true)
            minimizeQueue = nil
        } else {
            minimizes.beginRepeat()
            minimizeQueue = MinimizeCandidates.queue(
                settings: settings, excluding: minimizes.unconfirmed.map(\.window))
        }
    }

    func endRepeat() {
        let candidates = focusCandidates?.upcoming()
        minimizeQueue = nil
        focusCandidates = nil
        let schedule = SettleSchedule(
            start: ProcessInfo.processInfo.systemUptime,
            pendingCount: restores.unconfirmed.count + minimizes.unconfirmed.count)
        settleTask = Task {
            var focused = false
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(SettleSchedule.checkInterval))
                guard !Task.isCancelled else { return }
                let now = ProcessInfo.processInfo.systemUptime
                let phase = schedule.phase(at: now)
                guard phase != .early else { continue }
                var busy = BusyGroups<pid_t>()
                restores.resolve(
                    phase: phase, minimizedState: { readMinimizedState($0, &busy) }, abandon: { stack.putBack($0) })
                minimizes.resolve(phase: phase, minimizedState: { readMinimizedState($0, &busy) }, abandon: { _ in })
                if !focused {
                    focused = settleFocus(candidates: candidates, expired: phase == .expired, busy: &busy)
                }
                if focused && restores.isResolved && minimizes.isResolved { break }
            }
            settleTask = nil
        }
    }

    // 가장 최근 최소화 창부터 하나씩 복원한다.
    func restoreNext() -> RepeatPolicy.Progress {
        guard restoreFromStack(pop: { stack.popLast() }, isWaiting: awaitsRestore) == nil else { return .sent }
        guard stack.last == nil else { return .blocked }
        return restoreFrontmostMinimizedWindow()
    }

    // `pop` 이 꺼낸 창부터 최소화된 창 하나를 복원한다.
    private func restoreFromStack(pop: () -> WindowEntry?, isWaiting: (WindowEntry) -> Bool) -> WindowEntry? {
        RepeatPolicy.restoreNext(
            pop: pop, putBack: { stack.putBack($0) }, moveToBottom: { stack.insertAtBottom($0) }, key: \.window,
            stall: &restoreStall, now: ProcessInfo.processInfo.systemUptime, isWaiting: isWaiting,
            minimizedState: { $0.window.minimizedState },
            restore: { restore($0) })
    }

    // frontmost 앱의 최소화된 창 중 보낸 복원이 없는 창 하나를 복원한다.
    private func restoreFrontmostMinimizedWindow() -> RepeatPolicy.Progress {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return .idle }
        let windows: [ManagedWindow]
        do throws(AccessibilityError) {
            windows = try ManagedWindow.windows(of: pid)
        } catch .cannotComplete {
            return .blocked
        } catch {
            return .idle
        }
        var unknown = false
        for window in windows where !restores.unconfirmed.contains(where: { $0.window == window }) {
            switch window.minimizedState {
            case true?: break
            case false?: continue
            case nil:
                unknown = true
                continue
            }
            let entry = WindowEntry(pid: pid, window: window)
            guard !awaitsRestore(entry) else { return .blocked }
            switch restore(entry) {
            case .success: return .sent
            case .busy: return .blocked
            case .failure: continue
            }
        }
        return unknown ? .blocked : .idle
    }

    // 맨 앞 창부터 하나씩 최소화한다.
    func minimizeNext() -> RepeatPolicy.Progress {
        guard
            RepeatPolicy.advance(
                peek: { minimizeQueue?.peek() }, drop: { minimizeQueue?.drop() }, isWaiting: awaitsMinimize,
                attempt: { minimize($0) }) != nil
        else { return minimizeQueue?.isEmpty == false ? .blocked : .idle }
        focusCandidates = minimizeQueue
        return .sent
    }

    // 그 창의 앱에 보낸 복원이 아직 반영되지 않았는지.
    private func awaitsRestore(_ entry: WindowEntry) -> Bool {
        restores.awaits(
            entry.pid, at: ProcessInfo.processInfo.systemUptime, minimizedState: { $0.window.minimizedState },
            abandon: { stack.putBack($0) })
    }

    // 그 창의 앱에 보낸 최소화가 아직 반영되지 않았는지.
    private func awaitsMinimize(_ entry: WindowEntry) -> Bool {
        minimizes.awaits(
            entry.pid, at: ProcessInfo.processInfo.systemUptime, minimizedState: { $0.window.minimizedState },
            abandon: { _ in })
    }

    /// 최소화를 기록하고 보낸다.
    private func minimize(_ entry: WindowEntry) -> RepeatPolicy.Attempt {
        let recorded = minimizes
        minimizes.record(entry, at: ProcessInfo.processInfo.systemUptime)
        let result = entry.window.setMinimized(true)
        if result != .success { minimizes = recorded }
        return result
    }

    /// 모든 복원이 거치는 곳.
    private func restore(_ entry: WindowEntry) -> RepeatPolicy.Attempt {
        let recorded = restores
        restores.record(entry, at: ProcessInfo.processInfo.systemUptime)
        let result = entry.window.setMinimized(false)
        if result != .success { restores = recorded }
        return result
    }
}
