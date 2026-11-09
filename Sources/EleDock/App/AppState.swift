import EleDockCore
import Foundation

/// 메뉴와 설정 창이 함께 보는 실행 중 상태.
final class AppState: ObservableObject {
    @Published var failedHotKeys: Set<Shortcut.Kind> = []
    /// 녹화 중인 단축키.
    @Published var recordingKind: Shortcut.Kind?
    // 업데이트를 확인할 수 있는지.
    @Published var canCheckForUpdates = false
}
