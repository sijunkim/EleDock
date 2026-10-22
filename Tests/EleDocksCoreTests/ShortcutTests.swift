import AppKit
import Carbon.HIToolbox
import Testing

@testable import EleDocksCore

struct ShortcutTests {
    @Test func defaultsAreCommandMAndCommandShiftM() {
        #expect(Shortcut.Kind.minimize.defaultValue == Shortcut(keyCode: UInt32(kVK_ANSI_M), modifiers: UInt32(cmdKey)))
        #expect(
            Shortcut.Kind.restore.defaultValue
                == Shortcut(keyCode: UInt32(kVK_ANSI_M), modifiers: UInt32(cmdKey | shiftKey)))
    }

    @Test func hotKeyIDRoundTrips() throws {
        let ids = Shortcut.Kind.allCases.map(\.hotKeyID)
        #expect(Set(ids).count == ids.count)
        for kind in Shortcut.Kind.allCases {
            #expect(Shortcut.Kind(hotKeyID: kind.hotKeyID) == kind)
        }
        #expect(Shortcut.Kind(hotKeyID: try #require(ids.max()) + 1) == nil)
    }

    @Test func otherKindIsTheOpposite() {
        for kind in Shortcut.Kind.allCases {
            #expect(kind.other != kind)
            #expect(kind.other.other == kind)
        }
    }

    @Test(arguments: [
        (UInt32(0), false),
        (UInt32(shiftKey), false),
        (UInt32(cmdKey), true),
        (UInt32(optionKey), true),
        (UInt32(controlKey | shiftKey), true),
    ])
    func requiredModifier(modifiers: UInt32, expected: Bool) {
        #expect(Shortcut(keyCode: 0, modifiers: modifiers).hasRequiredModifier == expected)
    }

    @Test func carbonConstantsMatchHIToolbox() {
        #expect(CarbonModifier.cmd == UInt32(cmdKey))
        #expect(CarbonModifier.shift == UInt32(shiftKey))
        #expect(CarbonModifier.option == UInt32(optionKey))
        #expect(CarbonModifier.control == UInt32(controlKey))
        #expect(CarbonKey.m == kVK_ANSI_M)
        #expect(CarbonKey.escape == kVK_Escape)
    }

    @Test func eventFlagsConvertToCarbon() {
        let all: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let shortcut = Shortcut(eventKeyCode: UInt16(kVK_ANSI_A), eventModifierFlags: all.rawValue)
        #expect(shortcut.keyCode == UInt32(kVK_ANSI_A))
        #expect(shortcut.modifiers == UInt32(cmdKey | shiftKey | optionKey | controlKey))

        let single: [(NSEvent.ModifierFlags, Int)] = [
            (.command, cmdKey), (.shift, shiftKey), (.option, optionKey), (.control, controlKey),
        ]
        for (flag, carbon) in single {
            #expect(Shortcut(eventKeyCode: 0, eventModifierFlags: flag.rawValue).modifiers == UInt32(carbon))
        }
    }

    @Test func eventFlagsIgnoreOtherModifiers() {
        let flags: NSEvent.ModifierFlags = [.capsLock, .function, .numericPad]
        #expect(Shortcut(eventKeyCode: 0, eventModifierFlags: flags.rawValue).modifiers == 0)
    }
}

struct ShortcutStoredValueTests {
    @Test func validStoredValueRoundTrips() {
        let shortcut = Shortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(optionKey | controlKey))
        let stored = Shortcut(storedKeyCode: Int(shortcut.keyCode), storedModifiers: Int(shortcut.modifiers))
        #expect(stored == shortcut)
    }

    @Test func largestEventKeyCodeIsAccepted() {
        let stored = Shortcut(storedKeyCode: Int(UInt16.max), storedModifiers: Int(cmdKey))
        #expect(stored?.keyCode == UInt32(UInt16.max))
    }

    @Test func storedNumberFromPropertyListIsAccepted() {
        let stored = Shortcut(
            storedKeyCode: NSNumber(value: kVK_ANSI_K), storedModifiers: NSNumber(value: cmdKey))
        #expect(stored == Shortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey)))
    }

    /// 저장소에 들어 있을 수 있는 값.
    enum Stored: Sendable {
        case int(Int)
        case string(String)
        case missing

        var value: Any? {
            switch self {
            case .int(let value): value
            case .string(let value): value
            case .missing: nil
            }
        }
    }

    @Test(arguments: [
        (Stored.int(-1), Stored.int(cmdKey)),
        (.int(Int(UInt32.max) + 1), .int(cmdKey)),
        (.int(Int(UInt16.max) + 1), .int(cmdKey)),
        (.int(kVK_ANSI_K), .int(-1)),
        (.int(kVK_ANSI_K), .int(shiftKey)),
        (.int(kVK_ANSI_K), .int(0)),
        (.string("40"), .int(cmdKey)),
        (.int(kVK_ANSI_K), .missing),
        (.missing, .int(cmdKey)),
    ])
    func invalidStoredValueIsRejected(keyCode: Stored, modifiers: Stored) {
        #expect(Shortcut(storedKeyCode: keyCode.value, storedModifiers: modifiers.value) == nil)
    }
}

struct ShortcutRecordingTests {
    private let other = Shortcut.Kind.restore.defaultValue

    @Test func plainEscapeCancels() {
        #expect(Shortcut(keyCode: UInt32(kVK_Escape), modifiers: 0).recordingOutcome(other: other) == .cancel)
    }

    @Test func escapeWithModifierIsRecordedLikeAnyKey() {
        #expect(
            Shortcut(keyCode: UInt32(kVK_Escape), modifiers: UInt32(shiftKey)).recordingOutcome(other: other)
                == .missingModifier)
        #expect(
            Shortcut(keyCode: UInt32(kVK_Escape), modifiers: UInt32(cmdKey)).recordingOutcome(other: other) == .accept)
    }

    @Test func missingModifierIsRejected() {
        #expect(Shortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: 0).recordingOutcome(other: other) == .missingModifier)
        #expect(
            Shortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(shiftKey)).recordingOutcome(other: other)
                == .missingModifier)
    }

    @Test func sameAsOtherShortcutIsRejected() {
        #expect(other.recordingOutcome(other: other) == .duplicate)
    }

    @Test func validCombinationIsAccepted() {
        #expect(Shortcut.Kind.minimize.defaultValue.recordingOutcome(other: other) == .accept)
    }
}

struct ShortcutDisplayTests {
    @Test func modifiersAreShownInMacOrder() {
        let shortcut = Shortcut(
            keyCode: UInt32(kVK_ANSI_M), modifiers: UInt32(cmdKey | shiftKey | optionKey | controlKey))
        #expect(shortcut.displayString { _ in "M" } == "⌃⌥⇧⌘M")
    }

    @Test func specialKeyDoesNotAskLayout() {
        let shortcut = Shortcut(keyCode: UInt32(kVK_F5), modifiers: UInt32(cmdKey))
        #expect(
            shortcut.displayString { _ in
                Issue.record("자판 조회가 불렸다")
                return "?"
            } == "⌘F5")
    }

    @Test func otherKeyAsksLayoutWithKeyCode() {
        let shortcut = Shortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(optionKey))
        #expect(shortcut.displayString { $0 == kVK_ANSI_K ? "K" : "?" } == "⌥K")
    }

    @Test func specialKeyTableMatchesHIToolbox() {
        let expected: [Int: String] = [
            kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫", kVK_Escape: "⎋",
            kVK_ForwardDelete: "⌦", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
            kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
            kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18",
            kVK_F19: "F19", kVK_F20: "F20", kVK_Help: "Help", kVK_ANSI_KeypadClear: "⌧", kVK_ANSI_KeypadEnter: "⌤",
        ]
        #expect(Shortcut.specialKeyNames == expected)
    }
}
