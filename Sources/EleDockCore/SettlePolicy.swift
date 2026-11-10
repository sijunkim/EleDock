import Foundation

/// 반복이 끝난 뒤 확정·포커스 확인 시각.
public struct SettleSchedule: Sendable {
    /// 시스템 애니메이션을 기다리는 시간.
    public static let earliestDelay: TimeInterval = 0.6
    /// 마감까지의 기본 여유.
    public static let baseWait: TimeInterval = 1.0
    /// 미확인 항목 하나당 마감에 더하는 시간.
    public static let perItemWait: TimeInterval = 0.6
    /// 마감 뒤 응답 지연을 더 기다리는 상한.
    public static let maximumExtension: TimeInterval = 2.0
    /// 확인 주기.
    public static let checkInterval: TimeInterval = 0.25

    /// 확인 단계.
    public enum Phase: Equatable, Sendable {
        /// 시스템 애니메이션을 기다린다.
        case early
        /// 알림을 기다린다.
        case waiting
        /// 조회로 판정한다.
        case due
        /// 응답 지연까지 판정한다.
        case expired
    }

    /// 확인을 시작하는 시각.
    public let earliest: TimeInterval
    /// 알림을 기다리는 마감.
    public let deadline: TimeInterval
    /// 응답 지연을 기다리는 상한.
    public let limit: TimeInterval

    /// `start` 에 미확인 항목 `pendingCount` 개로 시각을 정한다.
    public init(start: TimeInterval, pendingCount: Int) {
        earliest = start + Self.earliestDelay
        deadline = start + Self.baseWait + Double(pendingCount) * Self.perItemWait
        limit = deadline + Self.maximumExtension
    }

    /// `now` 의 확인 단계.
    public func phase(at now: TimeInterval) -> Phase {
        if now < earliest { return .early }
        if now < deadline { return .waiting }
        if now < limit { return .due }
        return .expired
    }
}

/// 앱에 보낸 최소화·복원 요청을 확정하고, 확정되지 않은 것을 가린다.
public struct Confirmations<Entry, Key: Equatable, App: Equatable> {
    private let key: (Entry) -> Key
    private let app: (Entry) -> App
    private let minimized: Bool
    /// 확정을 기다리는 요청과 보낸 시각.
    private var pending: [(entry: Entry, sentAt: TimeInterval)] = []
    private var sent: [Entry] = []
    private var confirmed: [Key] = []

    /// 항목 키, 항목의 앱, 요청하는 최소화 상태로 만든다.
    public init(key: @escaping (Entry) -> Key, app: @escaping (Entry) -> App, minimized: Bool) {
        self.key = key
        self.app = app
        self.minimized = minimized
    }

    /// 확정을 기다리는 요청.
    public var unconfirmed: [Entry] { pending.map(\.entry) }

    /// 확정을 기다리는 요청이 없다.
    public var isResolved: Bool { pending.isEmpty }

    /// 이번 반복에서 마지막으로 보낸 요청 중 확정된 것.
    public var focusTarget: Entry? {
        sent.last { confirmed.contains(key($0)) }
    }

    /// 새 반복을 시작한다.
    public mutating func beginRepeat() {
        sent = []
        confirmed = []
    }

    /// `now` 에 요청을 보냈다.
    public mutating func record(_ entry: Entry, at now: TimeInterval) {
        let id = key(entry)
        sent.removeAll { [key] in key($0) == id }
        sent.append(entry)
        if let index = pending.firstIndex(where: { key($0.entry) == id }) {
            pending[index].sentAt = now
        } else {
            confirmed.removeAll { $0 == id }
            pending.append((entry, now))
        }
    }

    /// 요청이 반영됐거나 창이 사라졌다.
    public mutating func confirm(_ id: Key) {
        drop(id)
        if !confirmed.contains(id) { confirmed.append(id) }
    }

    private mutating func drop(_ id: Key) {
        pending.removeAll { [key] in key($0.entry) == id }
    }

    /// 조건에 맞는 항목을 판정 없이 버린다.
    public mutating func discard(where shouldDiscard: (Entry) -> Bool) {
        pending.removeAll { shouldDiscard($0.entry) }
        sent.removeAll(where: shouldDiscard)
    }

    /// `owner` 앱에 반영을 기다리는 요청이 있는지.
    public mutating func awaits(
        _ owner: App, at now: TimeInterval, minimizedState: (Entry) -> Bool?, abandon: (Entry) -> Void
    ) -> Bool {
        for (entry, sentAt) in pending where app(entry) == owner {
            if minimizedState(entry) == minimized {
                confirm(key(entry))
            } else if now - sentAt >= RepeatPolicy.stallDuration {
                drop(key(entry))
                abandon(entry)
            } else {
                return true
            }
        }
        return false
    }

    /// `phase` 에 맞춰 보낸 요청을 판정한다.
    public mutating func resolve(
        phase: SettleSchedule.Phase, minimizedState: (Entry) -> Bool?, abandon: (Entry) -> Void
    ) {
        guard phase == .due || phase == .expired else { return }
        for entry in unconfirmed.reversed() {
            let state = minimizedState(entry)
            if state == minimized {
                confirm(key(entry))
            } else if state != nil || phase == .expired {
                drop(key(entry))
                abandon(entry)
            }
        }
    }
}

extension RepeatPolicy {
    /// 최소화 반복 뒤 포커스 판정.
    public enum MinimizeFocus<Entry> {
        /// 이 창에 포커스를 준다.
        case focus(Entry)
        /// 기다린다.
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
