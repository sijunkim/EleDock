import Testing

@testable import EleDockCore

struct SettingsKeysTests {
    @Test func keysMatchStoredNames() {
        #expect(SettingsKeys.hotKeysEnabled == "hotKeysEnabled")
        #expect(SettingsKeys.holdToRepeat == "holdToRepeatEnabled")
        #expect(SettingsKeys.excludedApps == "excludedBundleIDs")
        #expect(SettingsKeys.suppressMoveAlert == "suppressMoveToApplicationsAlert")
        #expect(SettingsKeys.appleLanguages == "AppleLanguages")
    }

    @Test func shortcutKeysMatchStoredNames() {
        #expect(SettingsKeys.keyCode(.minimize) == "minimizeKeyCode")
        #expect(SettingsKeys.modifiers(.minimize) == "minimizeModifiers")
        #expect(SettingsKeys.keyCode(.restore) == "restoreKeyCode")
        #expect(SettingsKeys.modifiers(.restore) == "restoreModifiers")
    }

    @Test func defaultsTurnOnHotKeysAndHoldToRepeat() {
        #expect(SettingsKeys.defaults == ["hotKeysEnabled": true, "holdToRepeatEnabled": true])
    }
}
