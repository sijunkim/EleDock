import AppKit
import CoreGraphics

/// 창 캡처에 필요한 화면 기록 권한.
final class ScreenRecordingPermission {
    /// 시스템 설정의 화면 기록 패널.
    private static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")

    /// 창 캡처를 쓸 수 있는 macOS 버전인지.
    static var isSupported: Bool {
        if #available(macOS 14, *) { true } else { false }
    }

    /// 이번 실행에서 권한을 요청한 적이 있다.
    private(set) var hasRequested = false

    var isGranted: Bool { CGPreflightScreenCaptureAccess() }

    /// 화면 기록 권한을 요청한다.
    func request() {
        guard hasRequested else {
            hasRequested = true
            CGRequestScreenCaptureAccess()
            return
        }
        guard let url = Self.settingsURL else { return }
        NSWorkspace.shared.open(url)
    }
}
