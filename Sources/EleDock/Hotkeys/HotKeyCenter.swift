import AppKit
import ApplicationServices
import Carbon.HIToolbox
import EleDockCore

/// 최소화·복원 전역 단축키를 등록·해제한다.
final class HotKeyCenter {
    /// 이 앱이 등록한 핫키임을 나타내는 EventHotKeyID.signature.
    nonisolated static let signature: OSType = "ELDK".utf8.reduce(0) { $0 << 8 | OSType($1) }

    private let state: AppState
    private let settings: AppSettings
    private let repeater: RepeatController
    private var handlerRef: EventHandlerRef?
    private var hotKeyRefs: [Shortcut.Kind: (ref: EventHotKeyRef, shortcut: Shortcut)] = [:]
    private var recordingMonitor: Any?

    init(state: AppState, settings: AppSettings, repeater: RepeatController) {
        self.state = state
        self.settings = settings
        self.repeater = repeater
    }

    // 핫키 이벤트 핸들러를 설치한다.
    func install() {
        guard handlerRef == nil else { return }
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        let userData = Unmanaged.passUnretained(self).toOpaque()
        var ref: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(), hotKeyHandler, eventTypes.count, &eventTypes, userData, &ref)
        if status == noErr { handlerRef = ref }
        update()
    }

    fileprivate func handle(_ kind: Shortcut.Kind, eventKind: UInt32) {
        switch eventKind {
        case UInt32(kEventHotKeyPressed): repeater.start(kind)
        case UInt32(kEventHotKeyReleased): repeater.stop()
        default: break
        }
    }

    /// "단축키 사용" 을 바꾸고 등록 상태를 맞춘다.
    func setEnabled(_ enabled: Bool) {
        settings.hotKeysEnabled = enabled
        update()
    }

    // 단축키 등록 상태를 맞춘다.
    func update(
        trusted: Bool = AXIsProcessTrusted(), frontmost: NSRunningApplication? = NSWorkspace.shared.frontmostApplication
    ) {
        let wanted = HotKeyPolicy.shouldRegister(
            trusted: trusted, enabled: settings.hotKeysEnabled, recording: state.recordingKind != nil,
            frontmostExcluded: settings.isExcluded(frontmost?.bundleIdentifier))
        var failed: Set<Shortcut.Kind> = []
        var unregistered = false
        for kind in Shortcut.Kind.allCases {
            let shortcut = settings.shortcut(kind)
            if let current = hotKeyRefs[kind], !wanted || current.shortcut != shortcut {
                UnregisterEventHotKey(current.ref)
                hotKeyRefs[kind] = nil
                unregistered = true
            }
            guard wanted, hotKeyRefs[kind] == nil else { continue }
            if let ref = register(shortcut, kind: kind) {
                hotKeyRefs[kind] = (ref, shortcut)
            } else {
                failed.insert(kind)
            }
        }
        if unregistered, repeater.activeMode?.stopsOnUnregister == true { repeater.stop() }
        if state.failedHotKeys != failed { state.failedHotKeys = failed }
    }

    private func register(_ shortcut: Shortcut, kind: Shortcut.Kind) -> EventHotKeyRef? {
        guard handlerRef != nil else { return nil }
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: kind.hotKeyID)
        guard
            RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
                == noErr
        else { return nil }
        return ref
    }

    // 단축키 녹화를 시작한다.
    func startRecording(_ kind: Shortcut.Kind, handler: @escaping @MainActor (NSEvent) -> Void) {
        stopRecording()
        state.recordingKind = kind
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated { handler(event) }
            return nil
        }
        update()
    }

    func stopRecording() {
        guard let monitor = recordingMonitor else { return }
        NSEvent.removeMonitor(monitor)
        recordingMonitor = nil
        state.recordingKind = nil
        update()
    }
}

// 이 앱의 핫키 이벤트를 처리한다.
private nonisolated func hotKeyHandler(_: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?)
    -> OSStatus
{
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
        nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
    guard status == noErr, hotKeyID.signature == HotKeyCenter.signature,
        let kind = Shortcut.Kind(hotKeyID: hotKeyID.id), let userData
    else { return OSStatus(eventNotHandledErr) }
    let eventKind = GetEventKind(event)
    let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated { center.handle(kind, eventKind: eventKind) }
    return noErr
}
