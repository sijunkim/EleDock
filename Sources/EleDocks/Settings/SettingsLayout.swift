import CoreGraphics

/// 설정 창 탭과 그 안 컨트롤의 크기.
enum SettingsLayout {
    static let width: CGFloat = 500
    static let generalHeight: CGFloat = 356
    /// 다시 시작 안내 행 높이.
    static let relaunchRowHeight: CGFloat = 40
    static let shortcutsHeight: CGFloat = 371
    /// 단축키 녹화 버튼 아래 오류 문구 한 줄 높이.
    static let recorderMessageRowHeight: CGFloat = 20
    static let exclusionsHeight: CGFloat = 324
    static let aboutHeight: CGFloat = 339
    static let aboutIconSize: CGFloat = 96
    static let aboutSpacing: CGFloat = 6
    static let aboutLinkSpacing: CGFloat = 16
    static let wordmarkEleSize: CGFloat = 30
    static let wordmarkDocksSize: CGFloat = 26
    /// "ELEGANCE + DOCK" 자간.
    static let brandTracking: CGFloat = 3
    static let exclusionListHeight: CGFloat = 180
    /// "이 단축키를 쓰는 앱" 목록 높이.
    static let conflictListHeight: CGFloat = 96
    static let exclusionButtonSpacing: CGFloat = 12
    static let appIconSize: CGFloat = 20
    static let emptySpacing: CGFloat = 12
    static let emptyTextSpacing: CGFloat = 4
    static let recorderMinWidth: CGFloat = 90
    static let recorderMessageSpacing: CGFloat = 4
}
