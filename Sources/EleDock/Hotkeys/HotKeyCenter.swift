import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine
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
    private var triggers: Set<AnyCancellable> = []
    private var recordingMonitor: Any? {
        didSet { if let oldValue { NSEvent.removeMonitor(oldValue) } }
    }

    init(state: AppState, settings: AppSettings, repeater: RepeatController) {
        self.state = state
        self.settings = settings
        self.repeater = repeater
    }

    // 핫키 이벤트 핸들러를 설치하고 등록 상태를 맞춘다.
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
        settings.didChange.sink { [weak self] in self?.reconcile() }.store(in: &triggers)
        NSWorkspace.shared.publisher(for: \.frontmostApplication, options: .new)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reconcile() }
            .store(in: &triggers)
        reconcile()
    }

    fileprivate func handle(_ kind: Shortcut.Kind, eventKind: UInt32) {
        switch eventKind {
        case UInt32(kEventHotKeyPressed): repeater.press(kind)
        case UInt32(kEventHotKeyReleased): release(kind)
        default: break
        }
    }

    /// 설정·맨 앞 앱·권한·녹화·반복 상태에 맞게 단축키를 등록하거나 해제한다.
    func reconcile() {
        let holding = repeater.isHeld
        let wanted = HotKeyPolicy.shouldRegister(
            trusted: AXIsProcessTrusted(), enabled: settings.hotKeysEnabled, recording: state.recordingKind != nil,
            frontmostExcluded: settings.isExcluded(NSWorkspace.shared.frontmostApplication?.bundleIdentifier),
            holding: holding)
        var failed: Set<Shortcut.Kind> = []
        var unregistered: Set<Shortcut.Kind> = []
        for kind in Shortcut.Kind.allCases {
            let shortcut = settings.shortcut(kind)
            if let current = hotKeyRefs[kind], !wanted || current.shortcut != shortcut {
                UnregisterEventHotKey(current.ref)
                hotKeyRefs[kind] = nil
                unregistered.insert(kind)
            }
            guard wanted, hotKeyRefs[kind] == nil else { continue }
            if let ref = register(shortcut, kind: kind) {
                hotKeyRefs[kind] = (ref, shortcut)
            } else {
                failed.insert(kind)
            }
        }
        if state.failedHotKeys != failed { state.failedHotKeys = failed }
        if holding, case .hotKey(let kind) = repeater.activeMode, unregistered.contains(kind) { release(kind) }
    }

    // 단축키를 뗀 것으로 하고 등록 상태를 맞춘다.
    private func release(_ kind: Shortcut.Kind) {
        repeater.release(kind)
        reconcile()
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
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated { handler(event) }
            return nil
        }
        state.recordingKind = kind
        reconcile()
    }

    func stopRecording() {
        guard state.recordingKind != nil else { return }
        recordingMonitor = nil
        state.recordingKind = nil
        reconcile()
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
