import CoreGraphics

/// 설정 창 탭과 그 안 컨트롤의 크기.
enum SettingsLayout {
    static let width: CGFloat = 500
    static let generalHeight: CGFloat = 356
    /// 다시 시작 안내 행 높이.
    static let relaunchRowHeight: CGFloat = 40
    static let shortcutsHeight: CGFloat = 217
    /// 단축키 녹화 버튼 아래 오류 문구 한 줄 높이.
    static let recorderMessageRowHeight: CGFloat = 20
    static let exclusionsHeight: CGFloat = 324
    static let exclusionListHeight: CGFloat = 180
    static let exclusionButtonSpacing: CGFloat = 12
    static let appIconSize: CGFloat = 20
    static let recorderMinWidth: CGFloat = 90
    static let recorderMessageSpacing: CGFloat = 4
}
