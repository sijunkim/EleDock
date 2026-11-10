import Combine
import EleDockCore
import Foundation

/// UserDefaults 에 저장하는 사용자 설정.
final class AppSettings: ObservableObject {
    private typealias Key = SettingsKeys

    private let defaults: UserDefaults
    private let domain: String

    /// 실행할 때 실제로 적용된 언어.
    private let launchLocalization = Bundle.main.preferredLocalizations.first

    /// 설정을 바꾼 뒤 보내는 알림.
    let didChange = PassthroughSubject<Void, Never>()

    /// 기본값을 등록하고 설정을 만든다.
    init(defaults: UserDefaults, domain: String) {
        self.defaults = defaults
        self.domain = domain
        defaults.register(defaults: Key.defaults)
    }

    /// "언어".
    var language: AppLanguage {
        get { AppLanguage(appleLanguages: appleLanguages(in: domain)) }
        set {
            change {
                if let value = newValue.appleLanguages {
                    defaults.set(value, forKey: Key.appleLanguages)
                } else {
                    defaults.removeObject(forKey: Key.appleLanguages)
                }
            }
        }
    }

    /// 언어를 적용하려면 다시 시작해야 하는지.
    var languageNeedsRelaunch: Bool {
        let system = appleLanguages(in: UserDefaults.globalDomain) ?? []
        return language.localization(available: Bundle.main.localizations, systemLanguages: system)
            != launchLocalization
    }

    /// "단축키 사용".
    var hotKeysEnabled: Bool {
        get { defaults.bool(forKey: Key.hotKeysEnabled) }
        set { change { defaults.set(newValue, forKey: Key.hotKeysEnabled) } }
    }

    /// "길게 눌러 연속 동작".
    var holdToRepeat: Bool {
        get { defaults.bool(forKey: Key.holdToRepeat) }
        set { change { defaults.set(newValue, forKey: Key.holdToRepeat) } }
    }

    /// 응용 프로그램 폴더 이동 안내 "다시 묻지 않기".
    var suppressMoveAlert: Bool {
        get { defaults.bool(forKey: Key.suppressMoveAlert) }
        set { change { defaults.set(newValue, forKey: Key.suppressMoveAlert) } }
    }

    /// 제외 앱의 번들 ID 목록.
    var excludedBundleIDs: [String] {
        defaults.stringArray(forKey: Key.excludedApps) ?? []
    }

    /// 제외 앱인지 확인한다.
    func isExcluded(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return excludedBundleIDs.contains(bundleID)
    }

    func addExcluded(_ bundleID: String) {
        guard !isExcluded(bundleID) else { return }
        change { defaults.set(excludedBundleIDs + [bundleID], forKey: Key.excludedApps) }
    }

    func removeExcluded(_ bundleID: String) {
        change { defaults.set(excludedBundleIDs.filter { $0 != bundleID }, forKey: Key.excludedApps) }
    }

    /// 저장된 단축키.
    func shortcut(_ kind: Shortcut.Kind) -> Shortcut {
        Shortcut(
            storedKeyCode: defaults.object(forKey: Key.keyCode(kind)),
            storedModifiers: defaults.object(forKey: Key.modifiers(kind))) ?? kind.defaultValue
    }

    func setShortcut(_ shortcut: Shortcut, for kind: Shortcut.Kind) {
        change {
            defaults.set(Int(shortcut.keyCode), forKey: Key.keyCode(kind))
            defaults.set(Int(shortcut.modifiers), forKey: Key.modifiers(kind))
        }
    }

    /// 모든 단축키를 기본값으로 되돌린다.
    func resetShortcuts() {
        change {
            for kind in Shortcut.Kind.allCases {
                defaults.removeObject(forKey: Key.keyCode(kind))
                defaults.removeObject(forKey: Key.modifiers(kind))
            }
        }
    }

    // 값을 바꾸고 바뀌기 전·후를 알린다.
    private func change(_ body: () -> Void) {
        objectWillChange.send()
        body()
        didChange.send()
    }

    private func appleLanguages(in domain: String) -> [String]? {
        defaults.persistentDomain(forName: domain)?[Key.appleLanguages] as? [String]
    }
}
