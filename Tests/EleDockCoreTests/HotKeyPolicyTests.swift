import Testing

@testable import EleDockCore

struct HotKeyPolicyTests {
    @Test func registersWhenTrustedEnabledIdleAndFrontmostAllowed() {
        #expect(
            HotKeyPolicy.shouldRegister(
                trusted: true, enabled: true, recording: false, frontmostExcluded: false, holding: false))
    }

    @Test(arguments: [
        (false, true, false, false),
        (true, false, false, false),
        (true, true, true, false),
        (true, true, false, true),
    ])
    func anyBlockingConditionUnregisters(trusted: Bool, enabled: Bool, recording: Bool, frontmostExcluded: Bool) {
        #expect(
            !HotKeyPolicy.shouldRegister(
                trusted: trusted, enabled: enabled, recording: recording, frontmostExcluded: frontmostExcluded,
                holding: false))
    }

    @Test func holdingKeepsRegistrationWhenFrontmostBecomesExcluded() {
        #expect(
            HotKeyPolicy.shouldRegister(
                trusted: true, enabled: true, recording: false, frontmostExcluded: true, holding: true))
    }

    @Test(arguments: [
        (false, true, false),
        (true, false, false),
        (true, true, true),
    ])
    func holdingDoesNotOverrideOtherConditions(trusted: Bool, enabled: Bool, recording: Bool) {
        #expect(
            !HotKeyPolicy.shouldRegister(
                trusted: trusted, enabled: enabled, recording: recording, frontmostExcluded: false, holding: true))
    }
}
