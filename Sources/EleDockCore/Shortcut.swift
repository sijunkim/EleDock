import Foundation

/// 전역 단축키 하나를 Carbon 키 코드와 수식키로 나타낸다.
public struct Shortcut: Equatable, Sendable {
    /// Carbon 가상 키 코드(kVK_*).
    public var keyCode: UInt32
    /// Carbon 수식키 마스크(cmdKey, shiftKey, optionKey, controlKey)의 합.
    public var modifiers: UInt32

    /// 단축키가 맡는 동작.
    public enum Kind: String, CaseIterable, Sendable {
        /// 맨 앞 창을 최소화한다.
        case minimize
        /// 가장 최근에 최소화한 창을 복원한다.
        case restore

        /// Carbon 핫키 ID.
        public var hotKeyID: UInt32 { UInt32(Self.allCases.firstIndex(of: self) ?? 0) }

        /// 핫키 ID 에 해당하는 동작.
        public init?(hotKeyID: UInt32) {
            guard Self.allCases.indices.contains(Int(hotKeyID)) else { return nil }
            self = Self.allCases[Int(hotKeyID)]
        }

        /// 저장값이 없을 때 쓰는 단축키.
        public var defaultValue: Shortcut {
            Shortcut(
                keyCode: UInt32(CarbonKey.m),
                modifiers: self == .restore ? CarbonModifier.cmd | CarbonModifier.shift : CarbonModifier.cmd)
        }
        /// 반대 동작.
        public var other: Kind { self == .minimize ? .restore : .minimize }
    }

    /// Carbon 값으로 만든다.
    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// NSEvent 의 키 코드와 수식키 플래그로 만든다.
    public init(eventKeyCode: UInt16, eventModifierFlags flags: UInt) {
        var carbon: UInt32 = 0
        if flags & EventModifierFlag.command != 0 { carbon |= CarbonModifier.cmd }
        if flags & EventModifierFlag.shift != 0 { carbon |= CarbonModifier.shift }
        if flags & EventModifierFlag.option != 0 { carbon |= CarbonModifier.option }
        if flags & EventModifierFlag.control != 0 { carbon |= CarbonModifier.control }
        self.init(keyCode: UInt32(eventKeyCode), modifiers: carbon)
    }

    /// 저장소에서 읽은 값으로 만든다.
    public init?(storedKeyCode: Any?, storedModifiers: Any?) {
        guard let code = storedKeyCode as? Int, let keyCode = UInt16(exactly: code).map(UInt32.init),
            let mods = storedModifiers as? Int, let modifiers = UInt32(exactly: mods)
        else { return nil }
        self.init(keyCode: keyCode, modifiers: modifiers)
        guard hasRequiredModifier else { return nil }
    }

    /// Cmd·Option·Control 중 하나가 있는지.
    public var hasRequiredModifier: Bool {
        modifiers & (CarbonModifier.cmd | CarbonModifier.option | CarbonModifier.control) != 0
    }

    /// 녹화기에 입력된 조합을 어떻게 처리할지 정한다.
    public enum RecordingOutcome: Equatable, Sendable {
        /// 녹화를 취소한다.
        case cancel
        /// 필수 수식키가 없어 거부한다.
        case missingModifier
        /// 다른 단축키와 같아 거부한다.
        case duplicate
        /// 받아들인다.
        case accept
    }

    /// 녹화기에 입력된 조합의 처리 방법을 정한다.
    public func recordingOutcome(other: Shortcut) -> RecordingOutcome {
        if Int(keyCode) == CarbonKey.escape && modifiers == 0 { return .cancel }
        if !hasRequiredModifier { return .missingModifier }
        if self == other { return .duplicate }
        return .accept
    }

    /// 수식키 기호와 키 이름으로 된 표시 문자열.
    public func displayString(layoutKeyName: (Int) -> String) -> String {
        var text = ""
        if modifiers & CarbonModifier.control != 0 { text += "⌃" }
        if modifiers & CarbonModifier.option != 0 { text += "⌥" }
        if modifiers & CarbonModifier.shift != 0 { text += "⇧" }
        if modifiers & CarbonModifier.cmd != 0 { text += "⌘" }
        let code = Int(keyCode)
        return text + (Shortcut.specialKeyNames[code] ?? layoutKeyName(code))
    }

    // 자판 배치·언어와 무관하게 이름이 정해진 키.
    static let specialKeyNames: [Int: String] = [
        CarbonKey.return: "↩", CarbonKey.tab: "⇥", CarbonKey.delete: "⌫",
        CarbonKey.escape: "⎋", CarbonKey.forwardDelete: "⌦", CarbonKey.leftArrow: "←",
        CarbonKey.rightArrow: "→", CarbonKey.upArrow: "↑", CarbonKey.downArrow: "↓", CarbonKey.home: "↖",
        CarbonKey.end: "↘", CarbonKey.pageUp: "⇞", CarbonKey.pageDown: "⇟",
        CarbonKey.f1: "F1", CarbonKey.f2: "F2", CarbonKey.f3: "F3", CarbonKey.f4: "F4", CarbonKey.f5: "F5",
        CarbonKey.f6: "F6", CarbonKey.f7: "F7", CarbonKey.f8: "F8", CarbonKey.f9: "F9", CarbonKey.f10: "F10",
        CarbonKey.f11: "F11", CarbonKey.f12: "F12", CarbonKey.f13: "F13", CarbonKey.f14: "F14",
        CarbonKey.f15: "F15", CarbonKey.f16: "F16", CarbonKey.f17: "F17", CarbonKey.f18: "F18",
        CarbonKey.f19: "F19", CarbonKey.f20: "F20", CarbonKey.keypadClear: "⌧",
        CarbonKey.keypadEnter: "⌤",
    ]
}
