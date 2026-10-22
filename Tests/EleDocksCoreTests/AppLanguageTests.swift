import Foundation
import Testing

@testable import EleDocksCore

struct AppLanguageTests {
    @Test(arguments: [
        (["ja"], AppLanguage.japanese),
        (["ko", "en"], .korean),
        (["en"], .english),
        (["ja-JP"], .japanese),
        (["en_US"], .english),
    ])
    func firstSupportedValueIsSelection(stored: [String], expected: AppLanguage) {
        #expect(AppLanguage(appleLanguages: stored) == expected)
    }

    @Test(arguments: [nil, [], ["fr"], ["fr", "ko"], ["system"], [""]] as [[String]?])
    func missingOrUnsupportedFirstValueIsSystem(stored: [String]?) {
        #expect(AppLanguage(appleLanguages: stored) == .system)
    }

    @Test func storedValueRoundTrips() {
        #expect(AppLanguage.system.appleLanguages == nil)
        for language in AppLanguage.allCases {
            #expect(AppLanguage(appleLanguages: language.appleLanguages) == language)
        }
    }

    @Test(arguments: [
        (AppLanguage.system, ["fr", "ja-JP"], "ja"),
        (.system, ["ko-KR", "en"], "ko"),
        (.english, ["ja-JP"], "en"),
        (.korean, ["en"], "ko"),
        (.japanese, ["ko"], "ja"),
    ])
    func localizationFollowsSelectionOrSystemOrder(language: AppLanguage, system: [String], expected: String) {
        #expect(language.localization(available: ["en", "ko", "ja"], systemLanguages: system) == expected)
    }

    @Test func onlySystemHasNoCodeOrNativeName() {
        #expect(AppLanguage.system.code == nil)
        #expect(AppLanguage.system.nativeName == nil)
        #expect(AppLanguage.allCases.map(\.nativeName) == [nil, "English", "한국어", "日本語"])
        #expect(AppLanguage.allCases.compactMap(\.code) == ["en", "ko", "ja"])
    }

    @Test func supportedCodesMatchResourceFolders() throws {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources")
        let folders = try FileManager.default.contentsOfDirectory(atPath: resources.path)
            .filter { $0.hasSuffix(".lproj") }
            .map { String($0.dropLast(".lproj".count)) }
        #expect(Set(folders) == Set(AppLanguage.allCases.compactMap(\.code)))
    }
}
