// Foundation 만으로 쓰는 Carbon(HIToolbox) 상수.

/// Carbon 핫키 수식키 마스크(cmdKey 등).
enum CarbonModifier {
    static let cmd: UInt32 = 1 << 8
    static let shift: UInt32 = 1 << 9
    static let option: UInt32 = 1 << 11
    static let control: UInt32 = 1 << 12
}

/// NSEvent.ModifierFlags 의 원시 값.
enum EventModifierFlag {
    static let shift: UInt = 1 << 17
    static let control: UInt = 1 << 18
    static let option: UInt = 1 << 19
    static let command: UInt = 1 << 20
}

/// Carbon 가상 키 코드(kVK_*).
enum CarbonKey {
    static let m = 0x2E
    static let `return` = 0x24
    static let tab = 0x30
    static let space = 0x31
    static let delete = 0x33
    static let escape = 0x35
    static let forwardDelete = 0x75
    static let leftArrow = 0x7B
    static let rightArrow = 0x7C
    static let downArrow = 0x7D
    static let upArrow = 0x7E
    static let home = 0x73
    static let end = 0x77
    static let pageUp = 0x74
    static let pageDown = 0x79
    static let f1 = 0x7A
    static let f2 = 0x78
    static let f3 = 0x63
    static let f4 = 0x76
    static let f5 = 0x60
    static let f6 = 0x61
    static let f7 = 0x62
    static let f8 = 0x64
    static let f9 = 0x65
    static let f10 = 0x6D
    static let f11 = 0x67
    static let f12 = 0x6F
    static let f13 = 0x69
    static let f14 = 0x6B
    static let f15 = 0x71
    static let f16 = 0x6A
    static let f17 = 0x40
    static let f18 = 0x4F
    static let f19 = 0x50
    static let f20 = 0x5A
    static let help = 0x72
    static let keypadClear = 0x47
    static let keypadEnter = 0x4C
}
