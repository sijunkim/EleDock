import CoreGraphics

/// 설정 창과 그 안 컨트롤의 크기.
enum SettingsLayout {
    static let sidebarWidth: CGFloat = 200
    static let detailWidth: CGFloat = 500
    static let height: CGFloat = 460
    static let aboutIconSize: CGFloat = 96
    static let aboutSpacing: CGFloat = 6
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
    static let shortcutButtonWidth: CGFloat = 130
    static let recorderMessageSpacing: CGFloat = 4
}
