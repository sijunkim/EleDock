import Foundation

/// 사용자 노출 문구를 Bundle.main 의 Localizable.strings 에서 찾는다.
// swift-format-ignore: AlwaysUseLowerCamelCase
nonisolated func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}
