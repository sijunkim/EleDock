import ApplicationServices
import Carbon.HIToolbox
import Testing

@testable import EleDocksCore

struct MenuShortcutTests {
    private static let shift = Int(AXMenuItemModifiers.shift.rawValue)
    private let commandM = Shortcut(keyCode: UInt32(kVK_ANSI_M), modifiers: UInt32(cmdKey))
    private let commandShiftM = Shortcut(keyCode: UInt32(kVK_ANSI_M), modifiers: UInt32(cmdKey | shiftKey))

    private func item(
        title: String = "Set Mark", identifier: String? = nil, character: String? = "M", virtualKey: Int? = nil,
        modifiers: Int = Self.shift
    ) -> MenuItemShortcut {
        MenuItemShortcut(
            menu: "Edit", title: title, identifier: identifier, character: character, virtualKey: virtualKey,
            modifiers: modifiers)
    }

    @Test(
        arguments: [
            (cmdKey, AXMenuItemModifiers()),
            (cmdKey | shiftKey, AXMenuItemModifiers.shift),
            (optionKey | controlKey, AXMenuItemModifiers([.option, .control, .noCommand])),
            (cmdKey | shiftKey | optionKey | controlKey, AXMenuItemModifiers([.shift, .option, .control])),
        ] as [(Int, AXMenuItemModifiers)])
    func carbonModifiersConvertToMenuMask(carbon: Int, mask: AXMenuItemModifiers) {
        #expect(Shortcut(keyCode: 0, modifiers: UInt32(carbon)).menuModifiers == Int(mask.rawValue))
    }

    @Test func characterMatchesKeyNameIgnoringCase() {
        #expect(commandShiftM.isUsed(by: item(character: "m"), keyName: "M"))
        #expect(!commandShiftM.isUsed(by: item(character: "N"), keyName: "M"))
    }

    @Test func differentModifiersDoNotMatch() {
        #expect(!commandM.isUsed(by: item(), keyName: "M"))
    }

    @Test func virtualKeyIsComparedWithKeyCode() {
        let arrow = Shortcut(keyCode: UInt32(kVK_LeftArrow), modifiers: UInt32(cmdKey))
        let left = item(character: "\u{F702}", virtualKey: kVK_LeftArrow, modifiers: 0)
        #expect(arrow.isUsed(by: left, keyName: nil))
        #expect(!commandM.isUsed(by: item(character: "M", virtualKey: kVK_ANSI_N, modifiers: 0), keyName: "M"))
    }

    @Test func missingKeyNameOrCharacterDoesNotMatch() {
        #expect(!commandShiftM.isUsed(by: item(), keyName: nil))
        #expect(!commandShiftM.isUsed(by: item(character: nil), keyName: "M"))
    }

    @Test func minimizeItemsAreNotConflicts() {
        let items = [
            item(title: "최소화", identifier: "performMiniaturize:", modifiers: 0),
            item(title: "최소화", identifier: "_NS:371", modifiers: 0),
            item(title: "MINIMIZE", identifier: "handleAction:", modifiers: 0),
        ]
        let titles = MenuItemShortcut.minimizeTitles(in: items)
        #expect(titles == ["최소화"])
        #expect(commandM.conflict(in: items, keyName: "M", minimizeTitles: titles) == nil)
    }

    @Test func minimizeRuleAppliesToAnyShortcut() {
        let minimize = item(title: "Minimize", modifiers: Self.shift)
        #expect(commandShiftM.conflict(in: [minimize], keyName: "M", minimizeTitles: []) == nil)
    }

    @Test func firstNonMinimizeMatchIsTheConflict() {
        let mark = item()
        let items = [item(title: "Minimize"), item(title: "Other", character: "K"), mark]
        #expect(commandShiftM.conflict(in: items, keyName: "M", minimizeTitles: []) == mark)
    }
}
