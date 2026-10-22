import CoreGraphics
import Testing

@testable import EleDocksCore

struct FrameInterpolationTests {
    private let from = CGRect(x: 100, y: 200, width: 800, height: 600)
    private let to = CGRect(x: 1000.3, y: 1100.7, width: 48.1, height: 36.9)

    @Test func endpointsAreExact() {
        #expect(FrameInterpolation.interpolate(from: from, to: to, progress: 0) == from)
        #expect(FrameInterpolation.interpolate(from: from, to: to, progress: 1) == to)
    }

    @Test func halfwayIsMidpoint() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 50)
        let b = CGRect(x: 200, y: 100, width: 300, height: 150)
        #expect(
            FrameInterpolation.interpolate(from: a, to: b, progress: 0.5)
                == CGRect(x: 100, y: 50, width: 200, height: 100))
    }

    @Test func overshootGoesPastTargetButSizeStaysNonNegative() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        let b = CGRect(x: 100, y: 100, width: 10, height: 10)
        let over = FrameInterpolation.interpolate(from: a, to: b, progress: 1.1)
        #expect(abs(over.minX - 110) < 1e-9)
        #expect(abs(over.width - 1) < 1e-9)
        let far = FrameInterpolation.interpolate(from: a, to: b, progress: 2)
        #expect(far.width == 0)
        #expect(far.height == 0)
    }

    @Test func keyframesStartAtFromAndEndAtTo() {
        let frames = FrameInterpolation.keyframes(from: from, to: to, curve: .spring, count: 18)
        #expect(frames.count == 18)
        #expect(frames.first == from)
        #expect(frames.last == to)
    }

    @Test func flippingTwiceRoundTrips() {
        let rect = CGRect(x: 10, y: 20, width: 300, height: 400)
        let flipped = FrameInterpolation.flipped(rect, primaryScreenHeight: 1080)
        #expect(flipped == CGRect(x: 10, y: 660, width: 300, height: 400))
        #expect(FrameInterpolation.flipped(flipped, primaryScreenHeight: 1080) == rect)
    }

    @Test func aspectFitKeepsRatioAndCenters() {
        let box = CGRect(x: 0, y: 0, width: 48, height: 48)
        #expect(
            FrameInterpolation.aspectFit(CGSize(width: 800, height: 400), into: box)
                == CGRect(x: 0, y: 12, width: 48, height: 24))
        #expect(
            FrameInterpolation.aspectFit(CGSize(width: 300, height: 600), into: box)
                == CGRect(x: 12, y: 0, width: 24, height: 48))
        #expect(FrameInterpolation.aspectFit(CGSize(width: 10, height: 10), into: box) == box)
    }

    @Test func aspectFitOfEmptySizeIsBoxCenter() {
        let box = CGRect(x: 10, y: 20, width: 40, height: 60)
        #expect(FrameInterpolation.aspectFit(.zero, into: box) == CGRect(x: 30, y: 50, width: 0, height: 0))
    }

    @Test(arguments: [
        (CGSize(width: 48, height: 48), false),
        (CGSize(width: 200, height: 100), false),
        (CGSize(width: 201, height: 10), true),
        (CGSize(width: 10, height: 201), true),
        (CGSize(width: 1000, height: 1000), true),
    ])
    func shrinkIgnoredBySideLength(size: CGSize, expected: Bool) {
        let original = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        #expect(
            FrameInterpolation.shrinkWasIgnored(original: original, actual: CGRect(origin: .zero, size: size))
                == expected)
    }

    @Test func shrinkIgnoredByAreaRatio() {
        let original = CGRect(x: 0, y: 0, width: 400, height: 250)
        #expect(
            !FrameInterpolation.shrinkWasIgnored(
                original: original, actual: CGRect(x: 0, y: 0, width: 150, height: 100)))
        #expect(
            FrameInterpolation.shrinkWasIgnored(original: original, actual: CGRect(x: 0, y: 0, width: 151, height: 100))
        )
    }

    @Test func downscaledLimitsLongestSide() {
        #expect(
            FrameInterpolation.downscaled(CGSize(width: 2048, height: 1024), maxLength: 1024)
                == CGSize(width: 1024, height: 512))
        #expect(
            FrameInterpolation.downscaled(CGSize(width: 1000, height: 3000), maxLength: 1024)
                == CGSize(width: 341, height: 1024))
        #expect(
            FrameInterpolation.downscaled(CGSize(width: 1024, height: 800), maxLength: 1024)
                == CGSize(width: 1024, height: 800))
        #expect(
            FrameInterpolation.downscaled(CGSize(width: 300, height: 200), maxLength: 1024)
                == CGSize(width: 300, height: 200))
    }
}
