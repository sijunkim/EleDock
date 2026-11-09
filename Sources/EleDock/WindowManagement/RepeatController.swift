import CoreGraphics
import EleDockCore
import Foundation

/// 최소화·복원을 반복한다.
final class RepeatController {
    private let tracker: WindowTracker
    private let settings: AppSettings
    private var timer: Timer?
    private var restoreAllBudget = RestoreAllBudget(minimizedCount: 0)

    /// 진행 중인 반복.
    private(set) var activeMode: RepeatMode?

    init(tracker: WindowTracker, settings: AppSettings) {
        self.tracker = tracker
        self.settings = settings
    }

    // 단축키 동작의 반복을 시작한다.
    func start(_ kind: Shortcut.Kind) {
        let mode = RepeatMode.hotKey(kind)
        guard activeMode != mode else { return }
        stop()
        tracker.beginRepeat(kind, repeats: settings.holdToRepeat)
        activeMode = mode
        let start = Date()
        tick(mode)
        guard settings.holdToRepeat else { return }
        schedule(from: start) {
            guard self.isHeld(kind) else { return self.stop() }
            self.tick(mode)
        }
    }

    func stop() {
        if activeMode != nil { tracker.endRepeat() }
        timer?.invalidate()
        timer = nil
        activeMode = nil
    }

    // 메뉴 "모두 복원".
    func restoreAll() {
        stop()
        tracker.beginRepeat(.restore, repeats: true)
        restoreAllBudget = RestoreAllBudget(minimizedCount: tracker.minimizedCount)
        let mode = RepeatMode.restoreAll
        activeMode = mode
        let start = Date()
        tick(mode)
        schedule(from: start) {
            if self.restoreAllBudget.consumeTick(minimizedCount: self.tracker.minimizedCount) {
                self.tick(mode)
            } else {
                self.stop()
            }
        }
    }

    // interval 마다 `body` 를 부른다.
    private func schedule(from start: Date, _ body: @escaping @MainActor @Sendable () -> Void) {
        let timer = Timer(
            fire: start.addingTimeInterval(RepeatPolicy.interval), interval: RepeatPolicy.interval, repeats: true
        ) { _ in
            MainActor.assumeIsolated(body)
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // 단축키가 지금 눌려 있는지.
    private func isHeld(_ kind: Shortcut.Kind) -> Bool {
        CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(settings.shortcut(kind).keyCode))
    }

    private func tick(_ mode: RepeatMode) {
        switch mode.action {
        case .restore: tracker.restoreNext()
        case .minimize: tracker.minimizeNext()
        }
    }
}
