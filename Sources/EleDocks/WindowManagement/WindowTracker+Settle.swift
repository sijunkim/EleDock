import AppKit
import EleDocksCore

/// 반복이 끝난 뒤 확정 판정에 쓰는 조회와 포커스.
extension WindowTracker {
    // 확정된 포커스 대상에 포커스를 준다.
    func settleFocus(
        candidates: [WindowEntry]?, expired: Bool, busy: inout BusyGroups<pid_t>
    ) -> Bool {
        guard let candidates else {
            guard restores.isResolved else { return false }
            if let entry = restores.focusTarget { entry.window.focus() }
            return true
        }
        switch RepeatPolicy.minimizeFocus(
            pending: candidates.first, candidates: candidates, app: \.pid, key: \.window, expired: expired,
            minimizedState: { readMinimizedState($0, &busy) })
        {
        case .focus(let entry): entry.window.focus()
        case .wait: return false
        case .none: break
        }
        return true
    }

    // 창의 최소화 여부를 읽는다.
    func readMinimizedState(_ entry: WindowEntry, _ busy: inout BusyGroups<pid_t>) -> Bool? {
        busy.read(entry.pid, isBusy: \.isDelay) {
            () throws(AccessibilityError) in try entry.window.minimizedAttribute
        }
    }

    // 맨 앞 앱의 포커스 창인지.
    func isFocusedInFrontmost(_ entry: WindowEntry) throws(AccessibilityError) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == entry.pid else { return false }
        do {
            return try ManagedWindow.focused(of: entry.pid) == entry.window
        } catch .cannotComplete {
            throw .cannotComplete
        } catch {
            return false
        }
    }
}
