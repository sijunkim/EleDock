import AppKit
import ServiceManagement

/// "로그인 시 열기"(SMAppService.mainApp) 상태를 보여 주고 바꾼다.
final class LoginItemController: ObservableObject {
    @Published private(set) var status = SMAppService.mainApp.status

    var isEnabled: Bool { status == .enabled }

    /// 승인 대기 상태를 반영한 레이블.
    func label(_ title: String, approval: String) -> String {
        status == .requiresApproval ? approval : title
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        if status != self.status { self.status = status }
    }

    func toggle() {
        defer { refresh() }
        if SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
            return
        }
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            NSAlert(error: error).runModal()
        }
    }
}
