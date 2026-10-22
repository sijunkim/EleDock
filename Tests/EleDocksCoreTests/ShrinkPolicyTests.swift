import Testing

@testable import EleDocksCore

struct ShrinkPolicyTests {
    private let attempt = AnimationTiming.axCallTimeout

    @Test func retriesWhileNextAttemptEndsWithinLimit() {
        #expect(ShrinkPolicy.canRetry(waited: .zero))
        let lastStart = AnimationTiming.shrinkWaitLimit - AnimationTiming.shrinkRetryInterval - attempt
        #expect(ShrinkPolicy.canRetry(waited: .seconds(lastStart) - .milliseconds(1)))
    }

    @Test func givesUpWhenNextAttemptWouldPassLimit() {
        let lastStart = AnimationTiming.shrinkWaitLimit - AnimationTiming.shrinkRetryInterval - attempt
        #expect(!ShrinkPolicy.canRetry(waited: .seconds(lastStart) + .milliseconds(1)))
        #expect(!ShrinkPolicy.canRetry(waited: .seconds(AnimationTiming.shrinkWaitLimit)))
    }

    @Test func attemptMustEndWithinLimit() {
        let lastStart = Duration.seconds(AnimationTiming.shrinkWaitLimit - attempt)
        #expect(ShrinkPolicy.canAttempt(waited: lastStart - .milliseconds(1)))
        #expect(!ShrinkPolicy.canAttempt(waited: lastStart + .milliseconds(1)))
    }

    @Test func retryIncludesRetryInterval() {
        let waited = Duration.seconds(AnimationTiming.unresponsiveTime)
        let afterSleep = waited + .seconds(AnimationTiming.shrinkRetryInterval)
        #expect(ShrinkPolicy.canRetry(waited: waited) == ShrinkPolicy.canAttempt(waited: afterSleep))
    }

    @Test func attemptsContinueUntilUnresponsiveTime() {
        let waited = Duration.seconds(AnimationTiming.unresponsiveTime - AnimationTiming.shrinkRetryInterval)
        #expect(ShrinkPolicy.canRetry(waited: waited - .milliseconds(1)))
    }

    @Test func attemptFitsInRepeatTick() {
        #expect(AnimationTiming.axCallTimeout < RepeatPolicy.interval)
    }
}
