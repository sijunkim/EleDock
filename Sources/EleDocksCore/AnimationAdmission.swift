/// 새 애니메이션 작업을 받을지 정한다.
public enum AnimationAdmission: Equatable, Sendable {
    /// 받는다.
    case accept
    /// 동시 오버레이 수가 상한에 닿았다.
    case overlayLimit
    /// 캡처 대기열이 상한에 닿았다.
    case captureQueueFull

    /// 진행 중인 작업 수와 캡처 대기 수로 받을지 판정한다.
    public static func evaluate(activeJobs: Int, pendingCaptures: Int, capturing: Bool) -> AnimationAdmission {
        guard activeJobs < AnimationTiming.maximumConcurrentOverlays else { return .overlayLimit }
        guard capturing, pendingCaptures >= AnimationTiming.maximumPendingCaptures else { return .accept }
        return .captureQueueFull
    }

    /// 최소화 요청의 처리 방법을 정한다.
    public static func minimize(activeJobs: Int, pendingCaptures: Int, queuedMinimizes: Int) -> MinimizeAdmission {
        switch evaluate(activeJobs: activeJobs, pendingCaptures: pendingCaptures, capturing: true) {
        case .accept: .animate
        case .captureQueueFull: .wait
        case .overlayLimit: queuedMinimizes > 0 ? .wait : .plain
        }
    }

    /// 직접 그리는 애니메이션을 쓸지 정한다.
    public static func isActive(enabled: Bool, isSupported: Bool, isGranted: Bool) -> Bool {
        enabled && isSupported && isGranted
    }
}

/// 최소화 요청을 어떻게 처리할지.
public enum MinimizeAdmission: Equatable, Sendable {
    /// 작업으로 받아 직접 그린다.
    case animate
    /// 기다린다.
    case wait
    /// 기본 동작으로 처리한다.
    case plain
}
