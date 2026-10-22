import Foundation
import Testing

@testable import EleDocksCore

struct AnimationTimingTests {
    @Test(arguments: [
        (0.0, 0.10), (0.05, 0.10), (0.10, 0.10), (0.30, 0.30), (0.33, 0.35), (0.32, 0.30), (1.00, 1.00), (5.0, 1.00),
        (-1.0, 0.10),
    ])
    func clampsToRangeAndRoundsToStep(value: Double, expected: Double) {
        #expect(abs(AnimationTiming.clampedDuration(value) - expected) < 1e-9)
    }

    @Test(arguments: [Double.nan, .infinity, -.infinity])
    func nonFiniteDurationFallsBackToDefault(value: Double) {
        #expect(AnimationTiming.clampedDuration(value) == AnimationTiming.defaultDuration)
    }

    @Test(arguments: [
        (0.10, 1.00), (1.00, 0.10), (0.80, 0.30), (0.77, 0.35), (0.78, 0.30), (0.0, 1.00), (2.0, 0.10),
    ])
    func sliderPositionMapsReversedAndRoundsToStep(position: Double, expected: Double) {
        #expect(abs(AnimationTiming.duration(sliderPosition: position) - expected) < 1e-9)
    }

    @Test(arguments: [0.10, 0.30, 0.55, 1.00])
    func sliderPositionRoundTrips(duration: Double) {
        let position = AnimationTiming.sliderPosition(duration: duration)
        #expect(abs(AnimationTiming.duration(sliderPosition: position) - duration) < 1e-9)
    }

    @Test func sliderPositionPutsSlowOnTheLeft() {
        #expect(AnimationTiming.sliderPosition(duration: 1.00) < AnimationTiming.sliderPosition(duration: 0.10))
        #expect(abs(AnimationTiming.sliderPosition(duration: 1.00) - AnimationTiming.minimumDuration) < 1e-9)
        #expect(abs(AnimationTiming.sliderPosition(duration: 9.0) - AnimationTiming.minimumDuration) < 1e-9)
    }

    @Test func storedDurationFallsBackToDefault() {
        #expect(AnimationTiming.duration(storedValue: nil) == 0.30)
        #expect(AnimationTiming.duration(storedValue: "0.5") == 0.30)
        #expect(AnimationTiming.duration(storedValue: 0.5) == 0.5)
        #expect(AnimationTiming.duration(storedValue: NSNumber(value: 0.75)) == 0.75)
        #expect(AnimationTiming.duration(storedValue: 9.0) == 1.0)
        #expect(AnimationTiming.duration(storedValue: Double.nan) == 0.30)
    }

    @Test func rangeAndDefaultMatchDesign() {
        #expect(AnimationTiming.minimumDuration == 0.10)
        #expect(AnimationTiming.maximumDuration == 1.00)
        #expect(AnimationTiming.defaultDuration == 0.30)
    }

    @Test(arguments: [(0.10, 12), (0.20, 12), (0.30, 18), (0.35, 21), (0.70, 42), (1.00, 60), (3.0, 60), (0.0, 12)])
    func sampleCountHasLowerBound(duration: Double, expected: Int) {
        #expect(AnimationTiming.sampleCount(duration: duration) == expected)
    }

    @Test func sampleTimesSpanZeroToOneEvenly() {
        #expect(AnimationTiming.sampleTimes(count: 5) == [0, 0.25, 0.5, 0.75, 1])
        #expect(AnimationTiming.sampleTimes(count: 1) == [0, 1])
        #expect(AnimationTiming.sampleTimes(count: 0) == [0, 1])
    }

    @Test(arguments: [(0.0, 1.0), (0.5, 1.0), (0.7, 1.0), (0.85, 0.5), (1.0, 0.0), (-1.0, 1.0), (2.0, 0.0)])
    func minimizeOpacityFadesAfterSeventyPercent(progress: Double, expected: Double) {
        #expect(abs(AnimationTiming.minimizeOpacity(progress: progress) - expected) < 1e-9)
    }

    @Test(arguments: [(0.0, 0.0), (0.1, 0.5), (0.2, 1.0), (0.6, 1.0), (1.0, 1.0), (-1.0, 0.0), (2.0, 1.0)])
    func restoreOpacityAppearsInFirstTwentyPercent(progress: Double, expected: Double) {
        #expect(abs(AnimationTiming.restoreOpacity(progress: progress) - expected) < 1e-9)
    }
}
