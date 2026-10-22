import Foundation

/// 줄여 둔 창 frame 을 원래대로 되돌리는 한 번의 시도에서 본 것.
public enum PutBackObservation: Equatable, Sendable {
    /// 원래 frame 이 됐거나 되돌릴 필요가 없다.
    case restored
    /// set 은 받아들여졌지만 다시 읽은 frame 이 원래 frame 이 아니다.
    case mismatched
    /// 앱이 응답하지 않았다.
    case unresponsive
    /// 앱이 속성을 지원하지 않거나 구현하지 않았다고 답했다.
    case unsupported
    /// 그 밖의 실패.
    case failed
}

/// 되돌리기 시도에서 본 것으로 다음 할 일을 정한다.
public enum PutBackPolicy {
    /// 앱이 거부한 것으로 보는 연속 불일치 수.
    public static let mismatchLimit = 2

    /// 다음 할 일.
    public enum Decision: Equatable, Sendable {
        /// 끝났다. 저장값을 지운다.
        case done
        /// 저장값을 두고 다시 시도한다.
        case retry(mismatches: Int)
        /// 앱이 거부했다. 저장값을 두고 그 앱을 lock 한다.
        case lock
    }

    /// 다음 할 일을 정한다.
    public static func decide(_ observation: PutBackObservation, mismatches: Int) -> Decision {
        switch observation {
        case .restored: .done
        case .unsupported: .lock
        case .mismatched: mismatches + 1 >= mismatchLimit ? .lock : .retry(mismatches: mismatches + 1)
        case .unresponsive, .failed: .retry(mismatches: 0)
        }
    }
}

/// 여러 되돌리기가 나눠 쓰는 일정 간격의 AX 시도 슬롯.
public struct AttemptSlots: Sendable {
    /// 슬롯 간격.
    public let interval: TimeInterval
    private var next = -TimeInterval.infinity

    /// `interval` 마다 슬롯 하나를 주도록 만든다.
    public init(interval: TimeInterval) {
        self.interval = interval
    }

    /// `now` 에 슬롯을 얻는다.
    public mutating func take(at now: TimeInterval) -> Bool {
        guard now >= next else { return false }
        next = now + interval
        return true
    }

    /// `now` 부터 다음 슬롯까지 남은 시간.
    public func wait(at now: TimeInterval) -> TimeInterval {
        max(next - now, 0)
    }
}
