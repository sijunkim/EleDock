/// 응답 지연으로 줄이지 못한 창을 다시 줄여 볼지 정한다.
public enum ShrinkPolicy {
    /// 다음 재시도에서 줄이기를 시도할 수 있는지.
    public static func canRetry(waited: Duration) -> Bool {
        canAttempt(waited: waited + .seconds(AnimationTiming.shrinkRetryInterval))
    }

    /// 지금 줄이기를 한 번 더 시도할 수 있는지.
    public static func canAttempt(waited: Duration) -> Bool {
        waited + .seconds(AnimationTiming.axCallTimeout) <= .seconds(AnimationTiming.shrinkWaitLimit)
    }
}
