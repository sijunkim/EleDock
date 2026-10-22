import Testing

@testable import EleDocksCore

struct AnimationAdmissionTests {
    private let overlays = AnimationTiming.maximumConcurrentOverlays
    private let captures = AnimationTiming.maximumPendingCaptures

    @Test func acceptsBelowLimits() {
        #expect(AnimationAdmission.evaluate(activeJobs: 0, pendingCaptures: 0, capturing: true) == .accept)
        #expect(
            AnimationAdmission.evaluate(activeJobs: overlays - 1, pendingCaptures: captures - 1, capturing: true)
                == .accept)
    }

    @Test func overlayLimitComesFirst() {
        #expect(
            AnimationAdmission.evaluate(activeJobs: overlays, pendingCaptures: 0, capturing: false) == .overlayLimit)
        #expect(
            AnimationAdmission.evaluate(activeJobs: overlays, pendingCaptures: captures, capturing: true)
                == .overlayLimit)
    }

    @Test func fullCaptureQueueOnlyStopsCapturingJobs() {
        #expect(
            AnimationAdmission.evaluate(activeJobs: captures, pendingCaptures: captures, capturing: true)
                == .captureQueueFull)
        #expect(
            AnimationAdmission.evaluate(activeJobs: captures, pendingCaptures: captures, capturing: false) == .accept)
    }

    @Test func minimizeAnimatesBelowLimits() {
        #expect(AnimationAdmission.minimize(activeJobs: 0, pendingCaptures: 0, queuedMinimizes: 0) == .animate)
    }

    @Test func minimizeWaitsWhileCaptureQueueIsFull() {
        #expect(
            AnimationAdmission.minimize(activeJobs: captures, pendingCaptures: captures, queuedMinimizes: captures)
                == .wait)
    }

    @Test func minimizeAtOverlayLimitWaitsOnlyBehindQueuedJobs() {
        #expect(AnimationAdmission.minimize(activeJobs: overlays, pendingCaptures: 0, queuedMinimizes: 1) == .wait)
        #expect(AnimationAdmission.minimize(activeJobs: overlays, pendingCaptures: 0, queuedMinimizes: 0) == .plain)
    }

    @Test func activeOnlyWhenEnabledSupportedAndGranted() {
        #expect(AnimationAdmission.isActive(enabled: true, isSupported: true, isGranted: true))
        #expect(!AnimationAdmission.isActive(enabled: false, isSupported: true, isGranted: true))
        #expect(!AnimationAdmission.isActive(enabled: true, isSupported: false, isGranted: true))
        #expect(!AnimationAdmission.isActive(enabled: true, isSupported: true, isGranted: false))
    }
}
