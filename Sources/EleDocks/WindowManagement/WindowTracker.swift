import AppKit
import EleDocksCore

/// 최소화 순서를 추적하고 창을 최소화·복원한다.
final class WindowTracker {
    /// 창 조작 AX 호출의 timeout.
    static let callTimeout: Float = 0.1

    private let settings: AppSettings
    private let observer = MinimizeObserver()
    private var stack = MinimizedStack<ManagedWindow>()

    /// 이번 동작에서 최소화할 남은 후보.
    private var minimizeQueue: [WindowEntry]?
    /// 최소화 반복이 끝날 때 포커스를 줄 후보.
    private var focusCandidates: [WindowEntry]?
    /// 복원에서 맨 위 창이 연속으로 막힌 횟수.
    private var restoreStall = RestoreStall<ManagedWindow>()
    /// 보낸 복원의 확정 상태.
    private(set) var restores = RestoreConfirmations<WindowEntry, ManagedWindow>(key: \.window)
    /// 보낸 최소화의 확정 상태.
    private var minimizes = MinimizeConfirmations<WindowEntry, ManagedWindow>(key: \.window)
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
        restores = RestoreConfirmations(key: \.window)
        minimizes = MinimizeConfirmations(key: \.window)
    }

    private func handle(_ event: MinimizeObserver.Event) {
        switch event {
        case .minimized(let entry):
            if let successors = minimizes.confirm(entry.window) {
                stack.insert(entry, below: successors)
            } else {
                stack.push(entry)
            }
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
        beginRepeat(.restore, repeats: false)
        _ = restoreFromStack(pop: {
            defer { taken = nil }
            return taken
        })
        endRepeat()
    }

    // `action` 방향의 동작을 시작한다.
    func beginRepeat(_ action: Shortcut.Kind, repeats: Bool) {
        settleTask?.cancel()
        settleTask = nil
        restores.beginRepeat()
        if action == .restore {
            minimizes = MinimizeConfirmations(key: \.window)
            minimizeQueue = nil
        } else {
            minimizes.beginRepeat()
            minimizeQueue = MinimizeCandidates.current(settings: settings)?.filter { entry in
                !minimizes.unconfirmed.contains { $0.window == entry.window }
            }
        }
        guard repeats else { return }
        observer.beginRepeat()
    }

    func endRepeat() {
        observer.endRepeat()
        for entry in restores.unconfirmed.reversed() { stack.putBack(entry) }
        let candidates = focusCandidates
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
                guard schedule.minimizePhase(at: now) != .early else { continue }
                var busy = BusyGroups<pid_t>()
                let returned = restores.resolve(phase: phase) { entry in
                    let state = readMinimizedState(entry, &busy)
                    if state == false { stack.remove(entry.window) }
                    return state
                }
                for entry in returned {
                    stack.putBack(entry)
                }
                let resends = minimizes.resolve(
                    phase: schedule.minimizePhase(at: now), minimizedState: { readMinimizedState($0, &busy) },
                    canResend: { entry in
                        schedule.allowsResend(at: now)
                            && busy.read(entry.pid, isBusy: \.isDelay) { () throws(AccessibilityError) in
                                try isFocusedInFrontmost(entry)
                            } == false
                    })
                for entry in resends {
                    _ = entry.window.setMinimized(true)
                }
                if !focused {
                    focused = settleFocus(candidates: candidates, expired: phase == .expired, busy: &busy)
                }
                if focused && restores.isResolved && minimizes.isResolved { break }
            }
            settleTask = nil
        }
    }

    // 가장 최근 최소화 창부터 하나씩 복원한다.
    func restoreNext() {
        let restored = restoreFromStack(pop: { stack.popLast() })
        if restored == nil, stack.last == nil { restoreFrontmostMinimizedWindow() }
    }

    // `pop` 이 꺼낸 창부터 최소화된 창 하나를 복원한다.
    private func restoreFromStack(pop: () -> WindowEntry?) -> WindowEntry? {
        RepeatPolicy.restoreNext(
            pop: pop, putBack: { stack.putBack($0) }, moveToBottom: { stack.insertAtBottom($0) }, key: \.window,
            stall: &restoreStall, now: ProcessInfo.processInfo.systemUptime,
            minimizedState: { $0.window.minimizedState },
            restore: { restore($0) })
    }

    // frontmost 앱의 최소화된 창 하나를 복원한다.
    private func restoreFrontmostMinimizedWindow() {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
            let window = (try? ManagedWindow.windows(of: pid))?.first(where: { $0.minimizedState == true })
        else { return }
        _ = restore(WindowEntry(pid: pid, window: window))
    }

    // 맨 앞 창부터 하나씩 최소화한다.
    func minimizeNext() {
        guard
            RepeatPolicy.advance(
                peek: { minimizeQueue?.first }, drop: { _ = minimizeQueue?.removeFirst() },
                attempt: { minimize($0) }, now: { ProcessInfo.processInfo.systemUptime }) != nil
        else { return }
        focusCandidates = minimizeQueue
    }

    /// 최소화를 기록하고 보낸다.
    private func minimize(_ entry: WindowEntry) -> RepeatPolicy.Attempt {
        let recorded = minimizes
        minimizes.record(entry)
        let result = entry.window.setMinimized(true)
        if result == .failure { minimizes = recorded }
        return result
    }

    /// 모든 복원이 거치는 곳.
    private func restore(_ entry: WindowEntry) -> RepeatPolicy.Attempt {
        let recorded = restores
        restores.record(entry)
        let result = entry.window.setMinimized(false)
        if result == .failure { restores = recorded }
        return result
    }
}
