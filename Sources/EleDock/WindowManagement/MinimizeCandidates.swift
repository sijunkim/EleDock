import AppKit
import EleDockCore

/// 최소화할 창 후보를 화면 앞쪽 순서로 구한다.
enum MinimizeCandidates {
    // 화면 앞쪽 앱 순서의 최소화 큐를 만든다. `pending` 창은 뺀다.
    static func queue(settings: AppSettings, excluding pending: [ManagedWindow]) -> MinimizeQueue<WindowEntry> {
        let info =
            CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        let zOrder = info.compactMap { window -> pid_t? in
            guard (window[kCGWindowLayer as String] as? Int) == 0 else { return nil }
            return window[kCGWindowOwnerPID as String] as? pid_t
        }
        let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let pids = MinimizeOrder.pids(zOrder: zOrder, frontmost: frontmost) { pid in
            guard let app = NSRunningApplication(processIdentifier: pid) else { return false }
            return MinimizeOrder.isCandidate(
                isRegular: app.activationPolicy == .regular, isExcluded: settings.isExcluded(app.bundleIdentifier))
        }
        return MinimizeQueue(pids: pids) { pid in
            windows(of: pid, focusedFirst: pid == frontmost)?.filter { !pending.contains($0.window) }
        }
    }

    // 앱의 최소화되지 않은 표준 창을 화면 앞쪽 순서로 구한다. 응답 지연이면 nil.
    private static func windows(of pid: pid_t, focusedFirst: Bool) -> [WindowEntry]? {
        var windows: [ManagedWindow]
        do throws(AccessibilityError) {
            windows = try ManagedWindow.windows(of: pid)
        } catch .cannotComplete {
            return nil
        } catch {
            return []
        }
        if focusedFirst, let focused = try? ManagedWindow.focused(of: pid) {
            windows.removeAll { $0 == focused }
            windows.insert(focused, at: 0)
        }
        do {
            return try windows.filter { try $0.isMinimizeCandidate }.map { WindowEntry(pid: pid, window: $0) }
        } catch {
            return nil
        }
    }
}
