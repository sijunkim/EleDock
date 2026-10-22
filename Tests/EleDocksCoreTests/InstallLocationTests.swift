import Testing

@testable import EleDocksCore

struct InstallLocationTests {
    private let home = "/Users/me"

    private func location(_ path: String, sameFile: Bool = false) -> InstallLocation {
        InstallLocation(path: path, homeDirectory: home, isSameFileAsInstalled: sameFile)
    }

    @Test func applicationsFoldersAreInstalled() {
        #expect(location("/Applications/EleDocks.app") == .applications)
        #expect(location("/Users/me/Applications/EleDocks.app") == .userApplications)
        #expect(!location("/Applications/EleDocks.app").needsMove)
        #expect(!location("/Users/me/Applications/EleDocks.app").needsMove)
    }

    @Test func otherPathNeedsMove() {
        #expect(location("/Users/me/Downloads/EleDocks.app") == .other)
        #expect(location("/Users/me/Downloads/EleDocks.app").needsMove)
    }

    @Test func prefixMustBeWholeFolderName() {
        #expect(location("/ApplicationsOld/EleDocks.app").needsMove)
        #expect(location("/Users/other/Applications/EleDocks.app").needsMove)
    }

    @Test func sameFileAsInstalledDoesNotMove() {
        let link = location("/Users/me/Desktop/EleDocks.app", sameFile: true)
        #expect(link == .sameFileAsInstalled)
        #expect(!link.needsMove)
    }

    @Test func folderPrefixWinsOverSameFile() {
        #expect(location("/Applications/EleDocks.app", sameFile: true) == .applications)
    }
}
