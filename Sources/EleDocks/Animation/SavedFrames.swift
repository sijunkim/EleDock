import AppKit
import ApplicationServices
import EleDocksCore

/// 애니메이션 동안 실제 창을 줄이고 원래 frame 으로 되돌린다.
final class SavedFrames {
    /// 되돌린 결과.
    enum Outcome {
        /// 끝났다. 저장값은 없다.
        case done
        /// 앱이 응답하지 않았거나 아직 원래 frame 을 확인하지 못했다.
        case busy
        /// 앱이 명시적으로 거부했다.
        case refused
        /// 기다리는 동안 취소됐거나 저장값이 바뀌었다.
        case cancelled
    }

    /// 되돌리기를 다시 예약하는 횟수 상한.
    private static let rescheduleLimit = 3

    private var entries: [AXUIElement: (pid: pid_t, frame: SavedFrame)] = [:]
    /// 창(최소화된 창 포함) frame 을 줄일 수 없는 앱의 번들 ID.
    private var lockedApps: Set<String> = []
    /// 번들 ID 가 없어 pid 로 기록한 앱.
    private var lockedPids: Set<pid_t> = []
    /// 예약된 비동기 되돌리기.
    private var scheduled: [AXUIElement: (token: Int, task: Task<Void, Never>)] = [:]
    private var lastToken = 0
    /// 연속 동작 중 모든 되돌리기가 나눠 쓰는 AX 시도 슬롯.
    private var repeatSlots = AttemptSlots(interval: AnimationTiming.putBackRetryInterval)
    /// 연속 동작 중이다.
    var isRepeating = false

    func contains(_ window: AXUIElement) -> Bool {
        entries[window] != nil
    }

    /// 줄이기 전 frame.
    func original(of window: AXUIElement) -> CGRect? {
        entries[window]?.frame.original
    }

    /// 최소화된 창의 원래 frame.
    func original(ofMinimized window: AXUIElement) throws(AccessibilityError) -> CGRect {
        if let original = original(of: window) { return original }
        return try window.frame(before: AXDeadline(seconds: AnimationTiming.axCallTimeout))
    }

    /// 앱이 창 frame 을 줄일 수 없는 것으로 기록돼 있다.
    func isLocked(_ pid: pid_t) -> Bool {
        guard let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier else {
            return lockedPids.contains(pid)
        }
        return lockedApps.contains(bundleID)
    }

    /// 앱이 창 frame 을 줄일 수 없는 것으로 기록한다.
    func lock(_ pid: pid_t) {
        guard let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier else {
            lockedPids.insert(pid)
            return
        }
        lockedApps.insert(bundleID)
    }

    /// 창을 `target` 으로 줄인다.
    func shrink(_ window: AXUIElement, pid: pid_t, from original: CGRect, to target: CGRect) -> Outcome {
        cancelScheduled(window)
        entries[window] = (pid, SavedFrame(original: original, shrunk: nil))
        let deadline = AXDeadline(seconds: AnimationTiming.axCallTimeout)
        do {
            do {
                try window.setFrame(target, before: deadline, sizeFirst: true)
            } catch .unsupported {
                lock(pid)
                return .refused
            }
            let actual = try window.frame(before: deadline)
            entries[window] = (pid, SavedFrame(original: original, shrunk: actual))
            guard !FrameInterpolation.shrinkWasIgnored(original: original, actual: actual) else {
                lock(pid)
                return .refused
            }
            return .done
        } catch .cannotComplete {
            return .busy
        } catch {
            return .refused
        }
    }

    /// 종료된 앱의 저장값·예약·pid lock 을 모두 버린다.
    func removeAll(pid: pid_t) {
        for (window, entry) in entries where entry.pid == pid {
            cancelScheduled(window)
        }
        entries = entries.filter { $0.value.pid != pid }
        lockedPids.remove(pid)
    }

    /// 한 번 되돌려 본다.
    @discardableResult
    func putBackOnce(_ window: AXUIElement) -> Outcome {
        guard let saved = entries[window]?.frame else { return .done }
        let deadline = AXDeadline(seconds: AnimationTiming.axCallTimeout)
        let observation = send(window, saved, before: deadline) ?? verify(window, saved, before: deadline)
        return conclude(PutBackPolicy.decide(observation, mismatches: 0), window, saved) ?? .busy
    }

    /// 되돌리기를 다시 시도한다.
    @discardableResult
    func putBack(
        _ window: AXUIElement, requiresUnminimized: Bool = false, extendsWhileRepeating: Bool = false,
        isCancelled: () -> Bool = { false }
    ) async -> Outcome {
        guard let saved = entries[window]?.frame else { return .done }
        var end = ContinuousClock.now + .seconds(AnimationTiming.putBackRetryWindow)
        var mismatches = 0
        func stopped() -> Bool { isCancelled() || Task.isCancelled || entries[window]?.frame != saved }
        while true {
            let observation: PutBackObservation
            guard await awaitSlot(stopped) else { return .cancelled }
            let state: Bool? =
                requiresUnminimized
                ? window.withMessagingTimeout(WindowTracker.callTimeout) { window.minimizedState } : false
            switch state {
            case true?:
                return .cancelled
            case nil:
                observation = .unresponsive
            case false?:
                if requiresUnminimized {
                    guard await awaitSlot(stopped) else { return .cancelled }
                }
                if let sent = send(window, saved, before: AXDeadline(seconds: AnimationTiming.axCallTimeout)) {
                    observation = sent
                } else {
                    try? await Task.sleep(for: .seconds(AnimationTiming.putBackVerifyDelay))
                    guard !stopped() else { return .cancelled }
                    guard await awaitSlot(stopped) else { return .cancelled }
                    observation = verify(window, saved, before: AXDeadline(seconds: AnimationTiming.axCallTimeout))
                }
            }
            let decision = PutBackPolicy.decide(observation, mismatches: mismatches)
            if let outcome = conclude(decision, window, saved) { return outcome }
            if isRepeating, extendsWhileRepeating {
                end = ContinuousClock.now + .seconds(AnimationTiming.putBackRetryWindow)
            }
            guard ContinuousClock.now < end else { return .busy }
            if case .retry(let count) = decision { mismatches = count }
            try? await Task.sleep(for: .seconds(AnimationTiming.putBackRetryInterval))
            guard !stopped() else { return .cancelled }
        }
    }

    /// `delay` 초 뒤 되돌리기를 시작하도록 예약한다.
    func schedulePutBack(_ window: AXUIElement, after delay: Double, requiresUnminimized: Bool = false) {
        schedule(window, after: delay, requiresUnminimized: requiresUnminimized, reschedules: 0)
    }

    private func schedule(_ window: AXUIElement, after delay: Double, requiresUnminimized: Bool, reschedules: Int) {
        cancelScheduled(window)
        lastToken += 1
        let token = lastToken
        let task = Task {
            try? await Task.sleep(for: .seconds(delay))
            let outcome =
                Task.isCancelled
                ? nil : await putBack(window, requiresUnminimized: requiresUnminimized, extendsWhileRepeating: true)
            guard scheduled[window]?.token == token else { return }
            scheduled[window] = nil
            guard outcome == .busy, contains(window), reschedules < Self.rescheduleLimit else { return }
            schedule(
                window, after: AnimationTiming.unresponsiveTime, requiresUnminimized: true,
                reschedules: reschedules + 1)
        }
        scheduled[window] = (token, task)
    }

    /// 곧바로 한 번 되돌려 본다.
    @discardableResult
    func putBackSoon(_ window: AXUIElement) -> Outcome {
        let outcome = putBackOnce(window)
        if outcome == .busy, !isPutBackScheduled(window) {
            schedulePutBack(window, after: AnimationTiming.unresponsiveTime)
        }
        return outcome
    }

    /// 예약된 되돌리기가 있다.
    func isPutBackScheduled(_ window: AXUIElement) -> Bool {
        scheduled[window] != nil
    }

    /// 최소화되지 않은 채 줄어 있는 창을 되돌린다.
    func putBackUnminimized() {
        for window in Array(entries.keys) {
            let state = window.withMessagingTimeout(WindowTracker.callTimeout) { window.minimizedState }
            guard state != true else { continue }
            if state == nil || putBackOnce(window) == .busy {
                schedulePutBack(window, after: 0, requiresUnminimized: true)
            }
        }
    }

    /// 예약을 멈추고 모두 한 번씩 되돌려 본다.
    func putBackAll() {
        for window in Array(entries.keys) {
            cancelScheduled(window)
            putBackOnce(window)
        }
        entries = [:]
    }

    // MARK: - 한 번의 시도

    // AX 시도 슬롯을 기다린다.
    private func awaitSlot(_ stopped: () -> Bool) async -> Bool {
        while isRepeating, !repeatSlots.take(at: ProcessInfo.processInfo.systemUptime) {
            try? await Task.sleep(for: .seconds(repeatSlots.wait(at: ProcessInfo.processInfo.systemUptime)))
            guard !stopped() else { return false }
        }
        return true
    }

    // 원래 frame 을 set 한다.
    private func send(_ window: AXUIElement, _ saved: SavedFrame, before deadline: AXDeadline) -> PutBackObservation? {
        do {
            let current = try window.frame(before: deadline)
            guard !saved.isOriginal(current), saved.shouldPutBack(current: current) else { return .restored }
            try window.setFrame(saved.original, before: deadline)
            return nil
        } catch {
            return Self.observation(error)
        }
    }

    private func verify(_ window: AXUIElement, _ saved: SavedFrame, before deadline: AXDeadline) -> PutBackObservation {
        do {
            return saved.isOriginal(try window.frame(before: deadline)) ? .restored : .mismatched
        } catch {
            return Self.observation(error)
        }
    }

    // 되돌리기 판정을 반영한다.
    private func conclude(_ decision: PutBackPolicy.Decision, _ window: AXUIElement, _ saved: SavedFrame) -> Outcome? {
        switch decision {
        case .done:
            if entries[window]?.frame == saved { entries[window] = nil }
            return .done
        case .lock:
            if let pid = entries[window]?.pid { lock(pid) }
            return .refused
        case .retry:
            return nil
        }
    }

    private func cancelScheduled(_ window: AXUIElement) {
        scheduled.removeValue(forKey: window)?.task.cancel()
    }

    private static func observation(_ error: AccessibilityError) -> PutBackObservation {
        switch error {
        case .invalidUIElement: .restored
        case .cannotComplete: .unresponsive
        case .unsupported: .unsupported
        case .other: .failed
        }
    }
}
