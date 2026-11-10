import AppKit
import Carbon.HIToolbox
import EleDockCore

extension Shortcut {
    init(event: NSEvent) {
        self.init(eventKeyCode: event.keyCode, eventModifierFlags: event.modifierFlags.rawValue)
    }

    var displayString: String {
        displayString { keyCode in
            switch keyCode {
            case kVK_Space: L("key.space")
            case kVK_Help: L("key.help")
            default: Shortcut.layoutKeyName(keyCode) ?? "?"
            }
        }
    }

    /// ASCII 자판 기준의 키 이름.
    static func layoutKeyName(_ keyCode: Int) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
            let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        var deadKeys: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = data.withUnsafeBytes { buffer in
            UCKeyTranslate(
                buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress, UInt16(keyCode), UInt16(kUCKeyActionDisplay),
                0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeys, chars.count, &length,
                &chars)
        }
        guard status == noErr, length > 0 else { return nil }
        let text = String(utf16CodeUnits: chars, count: length)
        guard !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
        return text.uppercased()
    }
}
