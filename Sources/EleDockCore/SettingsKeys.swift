/// UserDefaults 에 저장하는 설정의 키와 기본값.
public enum SettingsKeys {
    /// "단축키 사용".
    public static let hotKeysEnabled = "hotKeysEnabled"
    /// "길게 눌러 연속 동작".
    public static let holdToRepeat = "holdToRepeatEnabled"
    /// 제외 앱 번들 ID 목록.
    public static let excludedApps = "excludedBundleIDs"
    /// 응용 프로그램 폴더 이동 안내 "다시 묻지 않기".
    public static let suppressMoveAlert = "suppressMoveToApplicationsAlert"
    /// 앱 표시 언어.
    public static let appleLanguages = "AppleLanguages"

    /// 단축키 Carbon 키 코드.
    public static func keyCode(_ kind: Shortcut.Kind) -> String { "\(kind.rawValue)KeyCode" }
    /// 단축키 Carbon 수식키 마스크.
    public static func modifiers(_ kind: Shortcut.Kind) -> String { "\(kind.rawValue)Modifiers" }

    /// 저장값이 없을 때 쓰는 값.
    public static let defaults: [String: Bool] = [hotKeysEnabled: true, holdToRepeat: true]
}
