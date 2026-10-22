import AppKit
import ApplicationServices
import EleDocksCore

/// 반복이 끝난 뒤 확정 판정에 쓰는 조회와 포커스.
extension WindowTracker {
    // 확정된 포커스 대상에 포커스를 준다.
    func settleFocus(
        candidates: [WindowEntry]?, expired: Bool, busy: inout BusyGroups<pid_t>
    ) -> Bool {
        guard let candidates else {
            guard restores.isResolved else { return false }
            if let entry = restores.focusTarget { focus(entry) }
            return true
        }
        switch RepeatPolicy.minimizeFocus(
            pending: candidates.first, candidates: candidates, app: \.pid, key: \.window, expired: expired,
            minimizedState: { settledMinimizedState($0, &busy) })
        {
        case .focus(let entry): focus(entry)
        case .wait: return false
        case .none: break
        }
        return true
    }

    func settledMinimizedState(_ entry: WindowEntry, _ busy: inout BusyGroups<pid_t>) -> Bool? {
        if animator.isMinimizing(entry.window) { return true }
        return readMinimizedState(entry, &busy)
    }

    // 보낸 최소화의 반영 여부.
    func pendingMinimizeState(_ entry: WindowEntry, _ busy: inout BusyGroups<pid_t>) -> Bool? {
        if animator.isMinimizing(entry.window) { return nil }
        return readMinimizedState(entry, &busy)
    }

    // 창의 최소화 여부를 읽는다.
    private func readMinimizedState(_ entry: WindowEntry, _ busy: inout BusyGroups<pid_t>) -> Bool? {
        busy.read(entry.pid, isBusy: \.isDelay) {
            () throws(AccessibilityError) in
            try entry.window.withMessagingTimeout(Self.callTimeout) { () throws(AccessibilityError) in
                try entry.window.minimizedAttribute
            }
        }
    }

    // 맨 앞 앱의 포커스 창인지.
    func isFocusedInFrontmost(_ entry: WindowEntry) throws(AccessibilityError) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == entry.pid else { return false }
        let appElement = AXUIElement.application(pid: entry.pid)
        do {
            let focused = try appElement.withMessagingTimeout(Self.callTimeout) { () throws(AccessibilityError) in
                try appElement.attribute(kAXFocusedWindowAttribute)
            }
            return focused.map { CFEqual($0, entry.window) } ?? false
        } catch .cannotComplete {
            throw .cannotComplete
        } catch {
            return false
        }
    }
}
