import Testing

@testable import EleDockCore

struct InstallLocationTests {
    private let home = "/Users/me"

    private func location(_ path: String, sameFile: Bool = false) -> InstallLocation {
        InstallLocation(path: path, homeDirectory: home, isSameFileAsInstalled: sameFile)
    }

    @Test func applicationsFoldersAreInstalled() {
        #expect(location("/Applications/EleDock.app") == .applications)
        #expect(location("/Users/me/Applications/EleDock.app") == .userApplications)
        #expect(!location("/Applications/EleDock.app").needsMove)
        #expect(!location("/Users/me/Applications/EleDock.app").needsMove)
    }

    @Test func otherPathNeedsMove() {
        #expect(location("/Users/me/Downloads/EleDock.app") == .other)
        #expect(location("/Users/me/Downloads/EleDock.app").needsMove)
    }

    @Test func prefixMustBeWholeFolderName() {
        #expect(location("/ApplicationsOld/EleDock.app").needsMove)
        #expect(location("/Users/other/Applications/EleDock.app").needsMove)
    }

    @Test func sameFileAsInstalledDoesNotMove() {
        let link = location("/Users/me/Desktop/EleDock.app", sameFile: true)
        #expect(link == .sameFileAsInstalled)
        #expect(!link.needsMove)
    }

    @Test func folderPrefixWinsOverSameFile() {
        #expect(location("/Applications/EleDock.app", sameFile: true) == .applications)
    }
}
