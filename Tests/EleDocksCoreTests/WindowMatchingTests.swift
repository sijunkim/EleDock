import CoreGraphics
import Testing

@testable import EleDocksCore

struct WindowMatchingTests {
    private static let frame = CGRect(x: 100, y: 100, width: 800, height: 600)

    private static func candidate(
        pid: Int32 = 42, frame: CGRect = frame, title: String? = "Doc", layer: Int = 0
    ) -> WindowCandidate {
        WindowCandidate(pid: pid, frame: frame, title: title, layer: layer)
    }

    private static func match(title: String? = "Doc", _ candidates: [WindowCandidate]) -> Int? {
        WindowMatching.bestMatch(pid: 42, frame: frame, title: title, candidates: candidates)
    }

    @Test func uniqueMatchIsChosen() {
        let candidates = [Self.candidate(pid: 7), Self.candidate(), Self.candidate(frame: .zero)]
        #expect(Self.match(candidates) == 1)
        #expect(Self.match(title: nil, candidates) == 1)
    }

    @Test func noMatchIsNil() {
        #expect(Self.match([]) == nil)
        #expect(
            Self.match([Self.candidate(pid: 7), Self.candidate(frame: CGRect(x: 0, y: 0, width: 10, height: 10))])
                == nil)
    }

    @Test func frameToleranceIsOnePointInclusive() {
        let within = CGRect(x: 101, y: 99, width: 801, height: 599)
        let beyond = CGRect(x: 101.5, y: 100, width: 800, height: 600)
        #expect(Self.match([Self.candidate(frame: within)]) == 0)
        #expect(Self.match([Self.candidate(frame: beyond)]) == nil)
        #expect(Self.match([Self.candidate(frame: CGRect(x: 100, y: 100, width: 800, height: 601.5))]) == nil)
    }

    @Test func titleBreaksTie() {
        let candidates = [Self.candidate(title: "Other"), Self.candidate(title: "Doc"), Self.candidate(title: nil)]
        #expect(Self.match(candidates) == 1)
    }

    @Test func fullTieIsNil() {
        #expect(Self.match([Self.candidate(), Self.candidate()]) == nil)
        #expect(Self.match(title: nil, [Self.candidate(title: "A"), Self.candidate(title: "B")]) == nil)
        #expect(Self.match(title: "Doc", [Self.candidate(title: "A"), Self.candidate(title: "B")]) == nil)
    }

    @Test func nonZeroLayerIsIgnored() {
        #expect(Self.match([Self.candidate(layer: 3)]) == nil)
        #expect(Self.match([Self.candidate(layer: 25), Self.candidate()]) == 1)
    }
}
