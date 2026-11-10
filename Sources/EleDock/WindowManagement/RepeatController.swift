import EleDockCore
import Foundation

/// 최소화·복원을 반복한다.
final class RepeatController {
    private let tracker: WindowTracker
    private let settings: AppSettings
    private var timer: Timer?
    private var demand = PressDemand()
    private var restoreAllBudget = RestoreAllBudget(minimizedCount: 0)

    /// 진행 중인 반복.
    private(set) var activeMode: RepeatMode?

    /// 단축키가 눌려 있는지.
    var isHeld: Bool { demand.isHeld }

    init(tracker: WindowTracker, settings: AppSettings) {
        self.tracker = tracker
        self.settings = settings
    }

    // 단축키 누름 하나를 동작으로 보낸다.
    func press(_ kind: Shortcut.Kind) {
        let mode = RepeatMode.hotKey(kind)
        guard activeMode != mode else { return demand.press() }
        stop()
        tracker.beginRepeat(kind)
        activeMode = mode
        demand.press()
        run(mode)
    }

    // 단축키를 뗐다.
    func release(_ kind: Shortcut.Kind) {
        guard activeMode == .hotKey(kind) else { return }
        demand.release()
        if !demand.continues(repeats: settings.holdToRepeat) { stop() }
    }

    // 반복과 남은 동작을 모두 끝낸다.
    func stop() {
        if activeMode != nil { tracker.endRepeat() }
        timer?.invalidate()
        timer = nil
        activeMode = nil
        demand = PressDemand()
    }

    // 메뉴 "모두 복원".
    func restoreAll() {
        stop()
        tracker.beginRepeat(.restore)
        restoreAllBudget = RestoreAllBudget(minimizedCount: tracker.minimizedCount)
        activeMode = .restoreAll
        run(.restoreAll)
    }

    // tick 하나를 진행한다.
    private func run(_ mode: RepeatMode) {
        timer = nil
        let tickStart = Date()
        let progress =
            switch mode.action {
            case .restore: tracker.restoreNext()
            case .minimize: tracker.minimizeNext()
            }
        guard activeMode == mode else { return }
        let continues: Bool
        switch mode {
        case .hotKey:
            demand.record(progress, at: ProcessInfo.processInfo.systemUptime)
            continues = demand.continues(repeats: settings.holdToRepeat)
        case .restoreAll:
            continues = restoreAllBudget.consumeTick(minimizedCount: tracker.minimizedCount)
        }
        guard continues else { return stop() }
        let timer = Timer(
            fire: RepeatPolicy.nextFire(tickStart: tickStart, tickEnd: Date()), interval: 0, repeats: false
        ) { _ in
            MainActor.assumeIsolated { self.run(mode) }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
