import Foundation

/// 앱 안에서 고르는 표시 언어.
public enum AppLanguage: String, CaseIterable, Sendable {
    /// 시스템 설정의 언어 순서를 따른다.
    case system
    /// 영어.
    case english = "en"
    /// 한국어.
    case korean = "ko"
    /// 일본어.
    case japanese = "ja"

    /// lproj 이름과 같은 언어 코드.
    public var code: String? { self == .system ? nil : rawValue }

    /// 그 언어 자체로 쓴 이름.
    public var nativeName: String? {
        switch self {
        case .system: nil
        case .english: "English"
        case .korean: "한국어"
        case .japanese: "日本語"
        }
    }

    /// 앱 도메인의 `AppleLanguages` 값으로 현재 선택을 구한다.
    public init(appleLanguages: [String]?) {
        let language = appleLanguages?.first?.split(whereSeparator: { "-_".contains($0) }).first.map(String.init)
        self = Self.allCases.first { $0.code != nil && $0.code == language } ?? .system
    }

    /// 앱 도메인 `AppleLanguages` 에 쓸 값.
    public var appleLanguages: [String]? { code.map { [$0] } }

    /// 이 선택으로 실행하면 실제로 적용될 언어.
    public func localization(available: [String], systemLanguages: [String]) -> String? {
        Bundle.preferredLocalizations(from: available, forPreferences: appleLanguages ?? systemLanguages).first
    }
}
