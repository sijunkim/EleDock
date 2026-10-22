import Testing

@testable import EleDocksCore

struct SettingsKeysTests {
    @Test func keysMatchStoredNames() {
        #expect(SettingsKeys.hotKeysEnabled == "hotKeysEnabled")
        #expect(SettingsKeys.holdToRepeat == "holdToRepeatEnabled")
        #expect(SettingsKeys.excludedApps == "excludedBundleIDs")
        #expect(SettingsKeys.suppressMoveAlert == "suppressMoveToApplicationsAlert")
        #expect(SettingsKeys.appleLanguages == "AppleLanguages")
        #expect(SettingsKeys.customAnimationEnabled == "customAnimationEnabled")
        #expect(SettingsKeys.customAnimationDuration == "customAnimationDuration")
        #expect(SettingsKeys.customAnimationCurve == "customAnimationCurve")
    }

    @Test func shortcutKeysMatchStoredNames() {
        #expect(SettingsKeys.keyCode(.minimize) == "minimizeKeyCode")
        #expect(SettingsKeys.modifiers(.minimize) == "minimizeModifiers")
        #expect(SettingsKeys.keyCode(.restore) == "restoreKeyCode")
        #expect(SettingsKeys.modifiers(.restore) == "restoreModifiers")
    }

    @Test func defaultsTurnOnHotKeysAndHoldToRepeatButNotCustomAnimation() {
        #expect(
            SettingsKeys.defaults == [
                "hotKeysEnabled": true, "holdToRepeatEnabled": true, "customAnimationEnabled": false,
            ])
    }

    @Test func excludedAppsDropDuplicatesKeepingFirstOrder() {
        #expect(SettingsKeys.excludedBundleIDs(stored: ["b", "a", "b", "c", "a"]) == ["b", "a", "c"])
        #expect(SettingsKeys.excludedBundleIDs(stored: []).isEmpty)
    }
}
