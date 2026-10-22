import Foundation
import Testing

@testable import EleDocksCore

struct AnimationCurveTests {
    private static let samples = (0...200).map { Double($0) / 200 }

    @Test(arguments: AnimationCurve.allCases)
    func startsAtZeroAndEndsAtOne(curve: AnimationCurve) {
        #expect(curve.value(at: 0) == 0)
        #expect(abs(curve.value(at: 1) - 1) < 1e-12)
    }

    @Test(arguments: AnimationCurve.allCases)
    func clampsProgressOutsideZeroToOne(curve: AnimationCurve) {
        #expect(curve.value(at: -0.5) == curve.value(at: 0))
        #expect(curve.value(at: 1.5) == curve.value(at: 1))
    }

    @Test(arguments: [AnimationCurve.easeIn, .easeOut, .linear, .easeInOut])
    func nonSpringCurvesAreMonotonicAndStayInRange(curve: AnimationCurve) {
        let values = Self.samples.map(curve.value(at:))
        #expect(zip(values, values.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(values.allSatisfy { (0...1).contains($0) })
    }

    @Test func easeInOutIsSymmetric() {
        for t in Self.samples {
            let curve = AnimationCurve.easeInOut
            #expect(abs(curve.value(at: 1 - t) - (1 - curve.value(at: t))) < 1e-12)
        }
        #expect(AnimationCurve.easeInOut.value(at: 0.5) == 0.5)
    }

    @Test func easeInAndEaseOutMirrorEachOther() {
        for t in Self.samples {
            #expect(abs(AnimationCurve.easeOut.value(at: t) - (1 - AnimationCurve.easeIn.value(at: 1 - t))) < 1e-12)
        }
        #expect(AnimationCurve.easeIn.value(at: 0.5) == 0.125)
        #expect(AnimationCurve.easeOut.value(at: 0.5) == 0.875)
    }

    @Test func springReachesTargetLateAndOvershootsSlightly() {
        let times = (0...1000).map { Double($0) / 1000 }
        let values = times.map(AnimationCurve.spring.value(at:))
        let firstReach = zip(times, values).first { $0.1 >= 1 }?.0 ?? 0
        let peak = values.max() ?? 0
        #expect(firstReach >= 0.5)
        #expect(peak > 1)
        #expect(peak <= 1.1)
        #expect(values.allSatisfy { $0 >= 0 })
        #expect(AnimationCurve.spring.value(at: 1) == 1)
    }

    @Test func rawValuesMatchStoredNames() {
        #expect(AnimationCurve.allCases.map(\.rawValue) == ["easeIn", "easeOut", "linear", "easeInOut", "spring"])
    }

    @Test func defaultIsEaseOut() {
        #expect(AnimationCurve.defaultValue == .easeOut)
    }

    @Test func storedValueFallsBackToDefault() {
        #expect(AnimationCurve(storedValue: "spring") == .spring)
        #expect(AnimationCurve(storedValue: nil) == .easeOut)
        #expect(AnimationCurve(storedValue: "bounce") == .easeOut)
        #expect(AnimationCurve(storedValue: 3) == .easeOut)
    }
}
