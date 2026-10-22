import AppKit
import ApplicationServices
import EleDocksCore

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
            let appElement = AXUIElement.application(pid: pid)
            var windows: [AXUIElement]
            do throws(AccessibilityError) {
                windows = try appElement.withMessagingTimeout(WindowTracker.callTimeout) {
                    () throws(AccessibilityError) in try appElement.windows
                }
            } catch .cannotComplete {
                return nil
            } catch {
                return []
            }
            if pid == frontmost,
                let focusedWindow = appElement.withMessagingTimeout(
                    WindowTracker.callTimeout, { appElement.focusedWindow })
            {
                windows.removeAll { $0 == focusedWindow }
                windows.insert(focusedWindow, at: 0)
            }
            do {
                return try windows.filter(isCandidate).map { WindowEntry(pid: pid, window: $0) }
            } catch {
                return nil
            }
        }
    }

    // 최소화되지 않은 표준 창인지 본다.
    private static func isCandidate(_ window: AXUIElement) throws(AccessibilityError) -> Bool {
        try window.withMessagingTimeout(WindowTracker.callTimeout) { () throws(AccessibilityError) in
            do throws(AccessibilityError) {
                guard try !window.minimizedAttribute else { return false }
            } catch .cannotComplete {
                throw .cannotComplete
            } catch {}
            do throws(AccessibilityError) {
                return try window.attribute(kAXSubroleAttribute) as? String == kAXStandardWindowSubrole
            } catch .cannotComplete {
                throw .cannotComplete
            } catch {
                return false
            }
        }
    }
}
