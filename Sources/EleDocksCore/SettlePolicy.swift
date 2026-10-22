import Foundation

/// 반복이 끝난 뒤 복원 확정·포커스 확인 시각.
public struct SettleSchedule: Sendable {
    /// 포커스를 주기 전 시스템 애니메이션을 기다리는 시간.
    public static let earliestDelay = AnimationTiming.unresponsiveTime
    /// 마감까지의 기본 여유.
    public static let baseWait: TimeInterval = 1.0
    /// 미확인 항목 하나당 마감에 더하는 시간.
    public static let perItemWait: TimeInterval = 0.6
    /// 마감 뒤 응답 지연을 더 기다리는 상한.
    public static let maximumExtension: TimeInterval = 2.0
    /// 확인 주기.
    public static let checkInterval: TimeInterval = 0.25
    /// 키를 뗀 뒤 최소화를 다시 보낼 수 있는 시간.
    public static let resendLimit = baseWait + maximumExtension
    /// 키를 뗀 뒤 최소화 반영을 판정하기까지의 시간.
    public static let resendCheckDelay = baseWait

    /// 확인 단계.
    public enum Phase: Equatable, Sendable {
        /// 시스템 애니메이션을 기다린다.
        case early
        /// 알림을 기다린다.
        case waiting
        /// 마감이 지나 조회로 판정한다.
        case due
        /// 상한이 지나 응답 지연도 판정한다.
        case expired
    }

    /// 확인을 시작하는 시각.
    public let earliest: TimeInterval
    /// 알림을 기다리는 마감.
    public let deadline: TimeInterval
    /// 응답 지연을 기다리는 상한.
    public let limit: TimeInterval
    /// 최소화를 다시 보낼 수 있는 마지막 시각.
    public let resendEnd: TimeInterval
    /// 최소화 반영을 판정하는 시각.
    public let resendCheck: TimeInterval

    /// `start` 에 미확인 항목 `pendingCount` 개로 시각을 정한다.
    public init(start: TimeInterval, pendingCount: Int) {
        earliest = start + Self.earliestDelay
        deadline = start + Self.baseWait + Double(pendingCount) * Self.perItemWait
        limit = deadline + Self.maximumExtension
        resendEnd = start + Self.resendLimit
        resendCheck = start + Self.resendCheckDelay
    }

    /// `now` 의 확인 단계.
    public func phase(at now: TimeInterval) -> Phase {
        if now < earliest { return .early }
        if now < deadline { return .waiting }
        if now < limit { return .due }
        return .expired
    }

    /// `now` 의 최소화 확인 단계.
    public func minimizePhase(at now: TimeInterval) -> Phase {
        if now < earliest { return .early }
        if now < resendCheck { return .waiting }
        if now < limit { return .due }
        return .expired
    }

    /// `now` 에 최소화를 다시 보낼 수 있는지.
    public func allowsResend(at now: TimeInterval) -> Bool {
        now < resendEnd
    }
}

/// 보낸 복원을 확정하고, 확정되지 않은 것을 가린다.
public struct RestoreConfirmations<Entry, Key: Equatable> {
    private let key: (Entry) -> Key
    /// 확정을 기다리는 복원.
    public private(set) var unconfirmed: [Entry] = []
    private var sent: [Entry] = []
    private var confirmed: [Key] = []

    /// 항목을 구분하는 키로 만든다.
    public init(key: @escaping (Entry) -> Key) {
        self.key = key
    }

    /// 확정을 기다리는 복원이 없다.
    public var isResolved: Bool { unconfirmed.isEmpty }

    /// 이번 반복에서 마지막으로 보낸 복원 중 확정된 것.
    public var focusTarget: Entry? {
        sent.last { confirmed.contains(key($0)) }
    }

    /// 새 반복을 시작한다.
    public mutating func beginRepeat() {
        sent = []
        confirmed = []
    }

    /// 복원을 보냈다.
    public mutating func record(_ entry: Entry, confirmed isConfirmed: Bool = false) {
        let id = key(entry)
        sent.removeAll { key($0) == id }
        sent.append(entry)
        if isConfirmed {
            confirm(id)
        } else if !unconfirmed.contains(where: { key($0) == id }) {
            confirmed.removeAll { $0 == id }
            unconfirmed.append(entry)
        }
    }

    /// 창이 복원됐거나 사라졌다.
    public mutating func confirm(_ id: Key) {
        unconfirmed.removeAll { key($0) == id }
        if !confirmed.contains(id) { confirmed.append(id) }
    }

    /// 조건에 맞는 항목을 판정 없이 버린다.
    public mutating func discard(where shouldDiscard: (Entry) -> Bool) {
        unconfirmed.removeAll(where: shouldDiscard)
        sent.removeAll(where: shouldDiscard)
    }

    /// `phase` 에 맞춰 판정하고, 스택에 되돌릴 항목을 돌려준다.
    public mutating func resolve(phase: SettleSchedule.Phase, minimizedState: (Entry) -> Bool?) -> [Entry] {
        guard phase == .due || phase == .expired else { return [] }
        var putBack: [Entry] = []
        for entry in unconfirmed {
            switch minimizedState(entry) {
            case false?:
                confirm(key(entry))
            case true?:
                putBack.append(entry)
            case nil:
                if phase == .expired { putBack.append(entry) }
            }
        }
        let returned = putBack.map(key)
        unconfirmed.removeAll { returned.contains(key($0)) }
        return putBack.reversed()
    }
}

/// 보낸 최소화를 확정하고, 최소화되지 않은 것을 가린다.
public struct MinimizeConfirmations<Entry, Key: Equatable> {
    private let key: (Entry) -> Key
    /// 확정을 기다리는 최소화.
    public private(set) var unconfirmed: [Entry] = []
    private var sent: [Key] = []
    /// 다시 보낸 최소화와 그보다 뒤에 보낸 창.
    private var resent: [(entry: Entry, successors: [Key])] = []

    /// 항목을 구분하는 키로 만든다.
    public init(key: @escaping (Entry) -> Key) {
        self.key = key
    }

    /// 확정을 기다리는 최소화가 없다.
    public var isResolved: Bool { unconfirmed.isEmpty }

    /// 새 반복을 시작한다.
    public mutating func beginRepeat() {
        resent = []
    }

    /// 최소화를 보냈다.
    public mutating func record(_ entry: Entry) {
        let id = key(entry)
        if unconfirmed.isEmpty && resent.isEmpty { sent = [] }
        unconfirmed.removeAll { key($0) == id }
        unconfirmed.append(entry)
        resent.removeAll { key($0.entry) == id }
        sent.removeAll { $0 == id }
        sent.append(id)
    }

    /// 창이 최소화됐거나 사라졌다.
    @discardableResult
    public mutating func confirm(_ id: Key) -> [Key]? {
        unconfirmed.removeAll { key($0) == id }
        guard let index = resent.firstIndex(where: { key($0.entry) == id }) else { return nil }
        return resent.remove(at: index).successors
    }

    /// 조건에 맞는 항목을 판정 없이 버린다.
    public mutating func discard(where shouldDiscard: (Entry) -> Bool) {
        unconfirmed.removeAll(where: shouldDiscard)
        resent.removeAll { shouldDiscard($0.entry) }
    }

    /// `phase` 에 맞춰 판정하고, 최소화를 다시 보낼 항목을 돌려준다.
    public mutating func resolve(
        phase: SettleSchedule.Phase, minimizedState: (Entry) -> Bool?, canResend: (Entry) -> Bool
    ) -> [Entry] {
        guard phase == .due || phase == .expired else { return [] }
        var resend: [Entry] = []
        var settled: [Key] = []
        for entry in unconfirmed {
            switch minimizedState(entry) {
            case false?:
                if canResend(entry) { resend.append(entry) }
                settled.append(key(entry))
            case true?:
                settled.append(key(entry))
            case nil:
                if phase == .expired { settled.append(key(entry)) }
            }
        }
        unconfirmed.removeAll { settled.contains(key($0)) }
        for entry in resend {
            let id = key(entry)
            resent.removeAll { key($0.entry) == id }
            resent.append((entry, Array(sent.drop { $0 != id }.dropFirst())))
        }
        return resend
    }
}

extension RepeatPolicy {
    /// 최소화 반복 뒤 포커스 판정.
    public enum MinimizeFocus<Entry> {
        /// 이 창에 포커스를 준다.
        case focus(Entry)
        /// 같은 앱 상태가 아직 확정되지 않았다.
        case wait
        /// 포커스를 주지 않는다.
        case none
    }

    /// 최소화 반복 뒤 포커스를 줄 창.
    public static func minimizeFocus<Entry, App: Equatable, Key: Equatable>(
        pending: Entry?, candidates: [Entry], app: (Entry) -> App, key: (Entry) -> Key, expired: Bool,
        minimizedState: (Entry) -> Bool?
    ) -> MinimizeFocus<Entry> {
        guard let pending else { return .none }
        let owner = app(pending)
        let others = candidates.filter { key($0) != key(pending) }
        var unknown = false
        for entry in [pending] + others.filter({ app($0) == owner }) {
            switch minimizedState(entry) {
            case false?: return .focus(entry)
            case true?: continue
            case nil:
                guard expired else { return .wait }
                unknown = true
            }
        }
        guard !unknown else { return .none }
        return others.first { app($0) != owner && minimizedState($0) == false }.map { .focus($0) } ?? .none
    }
}
