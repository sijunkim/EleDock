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
        tracker.beginRepeat(kind)
        activeMode = mode
        run(mode)
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
        tracker.beginRepeat(.restore)
        restoreAllBudget = RestoreAllBudget(minimizedCount: tracker.minimizedCount)
        activeMode = .restoreAll
        run(.restoreAll)
    }

    // tick 하나를 하고, 반복이 이어지면 tick 이 끝난 뒤 다음 tick 을 예약한다.
    private func run(_ mode: RepeatMode) {
        timer = nil
        let tickStart = Date()
        switch mode.action {
        case .restore: tracker.restoreNext()
        case .minimize: tracker.minimizeNext()
        }
        guard activeMode == mode else { return }
        switch mode {
        case .hotKey:
            guard settings.holdToRepeat else { return }
        case .restoreAll:
            guard restoreAllBudget.consumeTick(minimizedCount: tracker.minimizedCount) else { return stop() }
        }
        let timer = Timer(
            fire: RepeatPolicy.nextFire(tickStart: tickStart, tickEnd: Date()), interval: 0, repeats: false
        ) { _ in
            MainActor.assumeIsolated { self.run(mode) }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
