import CoreGraphics
import Testing

@testable import EleDocksCore

struct ScreenGeometryTests {
    private let left = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let right = CGRect(x: 1440, y: 0, width: 1920, height: 1080)

    @Test func picksScreenWithLargestOverlap() {
        let mostlyRight = CGRect(x: 1300, y: 100, width: 400, height: 300)
        #expect(ScreenGeometry.screen(for: mostlyRight, in: [left, right]) == right)
        let mostlyLeft = CGRect(x: 1200, y: 100, width: 400, height: 300)
        #expect(ScreenGeometry.screen(for: mostlyLeft, in: [left, right]) == left)
    }

    @Test func tieGoesToEarlierScreen() {
        let straddling = CGRect(x: 1340, y: 100, width: 200, height: 300)
        #expect(ScreenGeometry.screen(for: straddling, in: [left, right]) == left)
        #expect(ScreenGeometry.screen(for: straddling, in: [right, left]) == right)
    }

    @Test func noOverlapIsNil() {
        #expect(ScreenGeometry.screen(for: CGRect(x: -500, y: 0, width: 100, height: 100), in: [left, right]) == nil)
        #expect(ScreenGeometry.screen(for: CGRect(x: 1440, y: 0, width: 0, height: 0), in: [left, right]) == nil)
        #expect(ScreenGeometry.screen(for: left, in: []) == nil)
    }

    @Test func screenContainingPoint() {
        #expect(ScreenGeometry.screen(containing: CGPoint(x: 1500, y: 1000), in: [left, right]) == right)
        #expect(ScreenGeometry.screen(containing: CGPoint(x: 10, y: 10), in: [left, right]) == left)
        #expect(ScreenGeometry.screen(containing: CGPoint(x: 10, y: 950), in: [left, right]) == nil)
    }
}
