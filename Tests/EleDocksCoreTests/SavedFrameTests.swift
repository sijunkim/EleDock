import CoreGraphics
import Testing

@testable import EleDocksCore

struct SavedFrameTests {
    private let original = CGRect(x: 100, y: 200, width: 800, height: 600)
    private let shrunk = CGRect(x: 1000, y: 1100, width: 48, height: 36)

    @Test func putsBackWhileStillShrunk() {
        let saved = SavedFrame(original: original, shrunk: shrunk)
        #expect(saved.shouldPutBack(current: shrunk))
        #expect(saved.shouldPutBack(current: CGRect(x: 1000, y: 1100, width: 49.5, height: 34.5)))
    }

    @Test func putsBackEvenIfSystemMovedTheShrunkWindow() {
        let saved = SavedFrame(original: original, shrunk: shrunk)
        #expect(saved.shouldPutBack(current: CGRect(x: 300, y: 400, width: 48, height: 36)))
    }

    @Test func leavesWindowResizedAfterShrinking() {
        let saved = SavedFrame(original: original, shrunk: shrunk)
        #expect(!saved.shouldPutBack(current: CGRect(x: 1000, y: 1100, width: 400, height: 300)))
        #expect(!saved.shouldPutBack(current: CGRect(x: 1000, y: 1100, width: 48, height: 39)))
        #expect(!saved.shouldPutBack(current: original))
    }

    @Test func alwaysPutsBackWhenShrunkFrameIsUnknown() {
        let saved = SavedFrame(original: original, shrunk: nil)
        #expect(saved.shouldPutBack(current: CGRect(x: 0, y: 0, width: 300, height: 300)))
        #expect(saved.shouldPutBack(current: shrunk))
    }

    @Test func originalMatchesWithinTolerance() {
        let saved = SavedFrame(original: original, shrunk: shrunk)
        #expect(saved.isOriginal(original))
        #expect(saved.isOriginal(original.offsetBy(dx: 2, dy: -2)))
        #expect(!saved.isOriginal(original.offsetBy(dx: 2.5, dy: 0)))
        #expect(!saved.isOriginal(CGRect(x: 100, y: 200, width: 800, height: 597)))
        #expect(!saved.isOriginal(shrunk))
    }
}
