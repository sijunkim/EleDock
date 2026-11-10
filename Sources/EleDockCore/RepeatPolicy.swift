import Foundation

/// 진행 중인 반복의 종류.
public enum RepeatMode: Equatable, Sendable {
    /// 단축키를 누르고 있는 동안의 반복.
    case hotKey(Shortcut.Kind)
    /// 메뉴 "모두 복원".
    case restoreAll

    /// tick 마다 하는 동작.
    public var action: Shortcut.Kind {
        switch self {
        case .hotKey(let kind): kind
        case .restoreAll: .restore
        }
    }
}

/// 길게 누르기·모두 복원 반복의 규칙.
public enum RepeatPolicy {
    /// 반복 tick 간격.
    public static let interval: TimeInterval = 0.25

    /// 창 하나에 최소화·복원 set 을 보낸 결과.
    public enum Attempt: Sendable {
        /// 성공했다.
        case success
        /// 응답 지연(.cannotComplete).
        case busy
        /// 그 외 실패.
        case failure
    }

    /// tick 하나의 결과.
    public enum Progress: Sendable {
        /// 동작 하나를 보냈다.
        case sent
        /// 보낼 후보가 있지만 지금은 보낼 수 없다.
        case blocked
        /// 보낼 후보가 없다.
        case idle
    }

    /// 다음 tick 시각.
    public static func nextFire(tickStart: Date, tickEnd: Date) -> Date {
        let onTime = tickStart.addingTimeInterval(interval)
        return tickEnd < onTime ? onTime : tickEnd.addingTimeInterval(interval)
    }

    /// 한 tick 을 진행해 보낸 후보를 돌려준다.
    public static func advance<Entry>(
        peek: () -> Entry?, drop: () -> Void, isWaiting: (Entry) -> Bool, attempt: (Entry) -> Attempt
    ) -> Entry? {
        while let entry = peek() {
            guard !isWaiting(entry) else { return nil }
            switch attempt(entry) {
            case .success:
                drop()
                return entry
            case .busy:
                return nil
            case .failure:
                drop()
            }
        }
        return nil
    }

    /// 같은 항목을 포기하는 연속 막힘 횟수.
    public static let stallLimit = 2
    /// 같은 항목을 포기하기 전 기다리는 시간(초).
    public static let stallDuration: TimeInterval = 1.5

    /// 스택 맨 위부터 최소화된 창 하나를 복원해 그 항목을 돌려준다.
    public static func restoreNext<Entry, Key: Equatable>(
        pop: () -> Entry?, putBack: (Entry) -> Void, moveToBottom: (Entry) -> Void, key: (Entry) -> Key,
        stall: inout Stall<Key>, now: TimeInterval, isWaiting: (Entry) -> Bool, minimizedState: (Entry) -> Bool?,
        restore: (Entry) -> Attempt
    ) -> Entry? {
        var demoted: Key?
        while let entry = pop() {
            if let demoted, key(entry) == demoted {
                putBack(entry)
                return nil
            }
            if isWaiting(entry) {
                putBack(entry)
                return nil
            }
            if let minimized = minimizedState(entry) {
                guard minimized else { continue }
                switch restore(entry) {
                case .success:
                    stall.reset()
                    return entry
                case .failure:
                    continue
                case .busy:
                    break
                }
            }
            guard stall.recordStall(of: key(entry), at: now) else {
                putBack(entry)
                return nil
            }
            moveToBottom(entry)
            demoted = key(entry)
        }
        return nil
    }
}

/// 같은 항목이 연속으로 막힌 횟수와 처음 막힌 시각.
public struct Stall<Key: Equatable> {
    private var key: Key?
    private var count = 0
    private var firstStall: TimeInterval = 0

    /// 센 것이 없는 상태로 만든다.
    public init() {}

    /// `now` 에 `key` 항목이 막힌 것을 센다.
    public mutating func recordStall(of key: Key, at now: TimeInterval) -> Bool {
        if key == self.key {
            count += 1
        } else {
            count = 1
            firstStall = now
        }
        self.key = key
        guard count >= RepeatPolicy.stallLimit, now - firstStall >= RepeatPolicy.stallDuration else { return false }
        reset()
        return true
    }

    /// 센 것을 지운다.
    public mutating func reset() {
        key = nil
        count = 0
    }
}

/// 단축키 누름 중 아직 보내지 못한 동작과 키가 눌려 있는지.
public struct PressDemand {
    /// 아직 보내지 못한 누름 동작 수.
    public private(set) var pending = 0
    /// 단축키가 눌려 있는지.
    public private(set) var isHeld = false
    private var stall = Stall<Int>()

    /// 남은 것이 없는 상태로 만든다.
    public init() {}

    /// 단축키를 눌렀다.
    public mutating func press() {
        pending += 1
        isHeld = true
    }

    /// 단축키를 뗐다.
    public mutating func release() {
        isHeld = false
    }

    /// tick 을 이어 갈지. `repeats` 는 누르고 있는 동안 반복하는지.
    public func continues(repeats: Bool) -> Bool {
        pending > 0 || (isHeld && repeats)
    }

    /// `now` 에 끝난 tick 의 결과를 반영한다.
    public mutating func record(_ progress: RepeatPolicy.Progress, at now: TimeInterval) {
        switch progress {
        case .sent:
            pending = max(pending - 1, 0)
            stall.reset()
        case .idle:
            pending = 0
            stall.reset()
        case .blocked:
            guard pending > 0, stall.recordStall(of: 0, at: now) else { return }
            pending -= 1
        }
    }
}

/// "모두 복원" 의 tick 수 상한.
public struct RestoreAllBudget: Sendable {
    /// 최소화된 창 하나당 주는 tick 수.
    public static let ticksPerWindow = Int((RepeatPolicy.stallDuration / RepeatPolicy.interval).rounded(.up)) + 2

    private var remaining: Int

    /// 시작할 때 최소화된 창 수로 상한을 정한다.
    public init(minimizedCount: Int) {
        remaining = minimizedCount * Self.ticksPerWindow
    }

    /// tick 하나를 쓴다.
    public mutating func consumeTick(minimizedCount: Int) -> Bool {
        remaining -= 1
        return !(minimizedCount == 0 || remaining <= 0)
    }
}
