import AppKit
import EleDockCore

/// 최소화할 창 후보를 화면 앞쪽 순서로 구한다.
enum MinimizeCandidates {
    // 최소화되지 않은 표준 창 후보를 화면 앞쪽 순서로 구한다.
    static func current(settings: AppSettings) -> [WindowEntry]? {
        guard
            let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]]
        else {
            return []
        }
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
        return MinimizeOrder.windows(pids: pids, frontmost: frontmost) { pid -> [WindowEntry]? in
            var windows: [ManagedWindow]
            do throws(AccessibilityError) {
                windows = try ManagedWindow.windows(of: pid)
            } catch .cannotComplete {
                return nil
            } catch {
                return []
            }
            if pid == frontmost, let focused = try? ManagedWindow.focused(of: pid) {
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
}
