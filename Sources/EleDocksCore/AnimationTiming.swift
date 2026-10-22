import Foundation

/// 직접 그리는 애니메이션과 실제 창 조작의 시간 상수.
public enum AnimationTiming {
    /// 지속 시간 하한.
    public static let minimumDuration = 0.10
    /// 지속 시간 상한.
    public static let maximumDuration = 1.00
    /// 저장값이 없을 때 쓰는 지속 시간.
    public static let defaultDuration = 0.30
    /// 지속 시간을 맞추는 1초당 칸 수.
    public static let stepsPerSecond = 20.0

    /// 키프레임을 초당 몇 개 샘플링하는지.
    public static let samplesPerSecond = 60.0
    /// 키프레임 수 하한.
    public static let minimumSampleCount = 12

    /// 최소화 오버레이가 사라지기 시작하는 진행률.
    public static let minimizeFadeStart = 0.7
    /// 복원 오버레이가 다 나타나는 진행률.
    public static let restoreFadeEnd = 0.2
    /// 오버레이를 걷기 전 기다리는 시간.
    public static let restoreFadeOutDelay = 0.05
    /// 복원 오버레이를 걷는 페이드아웃 시간.
    public static let restoreFadeOutDuration = 0.08

    /// 캡처를 기다리는 상한.
    public static let captureTimeout = 1.0
    /// 창 조작 AX 호출의 timeout·예산.
    public static let axCallTimeout = 0.1
    /// 줄이기를 다시 시도하는 시간 상한.
    public static let shrinkWaitLimit = unresponsiveTime + axCallTimeout
    /// 줄이기를 다시 시도하는 간격.
    public static let shrinkRetryInterval = 0.05
    /// 최소화 작업 하나가 kAXMinimized 로 메인 스레드를 막는 누적 시간 상한.
    public static let minimizeBlockingLimit = 0.5
    /// kAXMinimized 를 다시 보내는 횟수.
    public static let minimizeRetries = 3
    /// kAXMinimized 를 다시 보내는 간격(초).
    public static let minimizeRetryInterval = 0.1
    /// 시스템 최소화·복원 애니메이션 동안 앱이 응답하지 않는 시간.
    public static let unresponsiveTime = 0.6
    /// 연속 동작 중 비동기 단계 사이에 메인 스레드를 넘기는 시간.
    public static let repeatHandoffDelay = 0.001
    /// 다시 읽어 확인하기 전 기다리는 시간.
    public static let putBackVerifyDelay = 0.05
    /// 되돌리기를 다시 시도하는 간격.
    public static let putBackRetryInterval = 0.05
    /// 첫 시도부터 되돌리기를 계속 시도하는 시간.
    public static let putBackRetryWindow = 1.0

    /// 최소화 작업 하나가 앞 작업 줄을 붙잡는 가장 긴 시간.
    public static let longestMinimizeRun =
        captureTimeout + shrinkWaitLimit + axCallTimeout + minimizeBlockingLimit
        + Double(minimizeRetries) * minimizeRetryInterval + Double(maximumMinimizeHandoffs) * repeatHandoffDelay
    /// 최소화 작업 하나가 연속 동작 중 메인 스레드를 넘기는 최대 횟수.
    public static let maximumMinimizeHandoffs = minimizeStageHandoffs + minimizeRetries + 1
    /// 최소화 작업 하나가 kAXMinimized 보내기 밖에서 메인 스레드를 넘기는 최대 횟수.
    private static let minimizeStageHandoffs = 3
    /// 최소화 작업이 앞 작업 줄을 기다리는 가장 긴 시간.
    public static let longestCaptureChainWait = Double(maximumPendingCaptures) * longestMinimizeRun - captureTimeout
    /// 최소화 작업이 오버레이를 붙잡는 가장 긴 시간.
    public static let longestMinimizeLifetime = longestCaptureChainWait + longestMinimizeRun + maximumDuration
    /// 복원 작업이 오버레이를 붙잡는 가장 긴 시간.
    public static let longestRestoreLifetime =
        max(maximumDuration, unresponsiveTime) + putBackRetryWindow + putBackRetryInterval + 2 * axCallTimeout
        + putBackVerifyDelay + restoreFadeOutDelay + restoreFadeOutDuration

    /// 동시에 진행하는 오버레이 수 상한.
    public static let maximumConcurrentOverlays = 33
    /// 캡처를 기다리는 최소화 작업 수 상한.
    public static let maximumPendingCaptures = 2

    /// 지속 시간을 범위로 자르고 칸 단위로 맞춘다.
    public static func clampedDuration(_ value: Double) -> Double {
        guard value.isFinite else { return defaultDuration }
        let clamped = min(max(value, minimumDuration), maximumDuration)
        return (clamped * stepsPerSecond).rounded() / stepsPerSecond
    }

    /// 속도 슬라이더 위치를 지속 시간으로 바꾼다.
    public static func duration(sliderPosition: Double) -> Double {
        clampedDuration(minimumDuration + maximumDuration - sliderPosition)
    }

    /// 지속 시간을 속도 슬라이더 위치로 바꾼다.
    public static func sliderPosition(duration: Double) -> Double {
        minimumDuration + maximumDuration - clampedDuration(duration)
    }

    /// 저장소에서 읽은 값으로 지속 시간을 구한다.
    public static func duration(storedValue: Any?) -> Double {
        guard let value = storedValue as? Double else { return defaultDuration }
        return clampedDuration(value)
    }

    /// `duration` 동안 쓸 키프레임 수.
    public static func sampleCount(duration: Double) -> Int {
        let steps = (clampedDuration(duration) * stepsPerSecond).rounded()
        return max(minimumSampleCount, Int((steps * samplesPerSecond / stepsPerSecond).rounded(.up)))
    }

    /// 0 부터 1 까지 고르게 나눈 시간 진행률 `count` 개.
    public static func sampleTimes(count: Int) -> [Double] {
        let count = max(count, 2)
        return (0..<count).map { Double($0) / Double(count - 1) }
    }

    /// 최소화 오버레이 투명도.
    public static func minimizeOpacity(progress: Double) -> Double {
        let t = min(max(progress, 0), 1)
        guard t > minimizeFadeStart else { return 1 }
        return (1 - t) / (1 - minimizeFadeStart)
    }

    /// 복원 오버레이 투명도.
    public static func restoreOpacity(progress: Double) -> Double {
        min(max(progress, 0) / restoreFadeEnd, 1)
    }
}
