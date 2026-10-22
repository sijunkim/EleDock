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

    /// 단축키 등록이 해제되면 반복을 끝내는지.
    public var stopsOnUnregister: Bool {
        if case .hotKey = self { return true }
        return false
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
        /// 보내지 않았다.
        case wait
        /// 그 외 실패.
        case failure
    }

    /// 한 tick 이 후보 시도에 쓰는 시간 상한.
    public static let tickBudget: TimeInterval = 0.2

    /// 한 tick 을 진행해 보낸 후보를 돌려준다.
    public static func advance<Entry>(
        peek: () -> Entry?, drop: () -> Void, attempt: (Entry) -> Attempt, now: () -> TimeInterval
    ) -> Entry? {
        let start = now()
        var longest: TimeInterval = 0
        while let entry = peek() {
            let attemptStart = now()
            guard attemptStart - start + longest <= tickBudget else { return nil }
            let result = attempt(entry)
            longest = max(longest, now() - attemptStart)
            if result == .wait { return nil }
            drop()
            if result == .success || result == .busy { return entry }
        }
        return nil
    }

    /// 같은 항목을 스택 맨 아래로 내리는 연속 막힘 횟수.
    public static let stallLimit = 2
    /// 같은 항목을 스택 맨 아래로 내리기 전 기다리는 시간(초).
    public static let stallDuration: TimeInterval = 1.5

    /// 스택 맨 위부터 최소화된 창 하나를 복원해 그 항목을 돌려준다.
    public static func restoreNext<Entry, Key: Equatable>(
        pop: () -> Entry?, putBack: (Entry) -> Void, moveToBottom: (Entry) -> Void, key: (Entry) -> Key,
        stall: inout RestoreStall<Key>, now: TimeInterval, minimizedState: (Entry) -> Bool?,
        restore: (Entry) -> Attempt
    ) -> Entry? {
        var demoted: Key?
        while let entry = pop() {
            if let demoted, key(entry) == demoted {
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
                case .busy, .wait:
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

/// 복원에서 같은 항목이 연속으로 막힌 횟수와 처음 막힌 시각.
public struct RestoreStall<Key: Equatable> {
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
