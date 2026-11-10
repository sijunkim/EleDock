import Testing

@testable import EleDockCore

struct InstallLocationTests {
    private let system = "/Applications/EleDock.app"
    private let user = "/Users/me/Applications/EleDock.app"
    private var installPaths: [String] { [system, user] }

    private func moves(_ path: String, sameFile: Set<String> = []) -> Bool {
        needsMove(path: path, installPaths: installPaths, sameFilePaths: sameFile)
    }

    @Test func installPathsDoNotMove() {
        #expect(!moves(system))
        #expect(!moves(user))
    }

    @Test func otherPathInApplicationsNeedsMove() {
        #expect(moves("/Applications/EleDock 2.app"))
        #expect(moves("/Users/me/Applications/EleDock 2.app"))
        #expect(moves("/Applications/Utilities/EleDock.app"))
    }

    @Test func outsideApplicationsNeedsMove() {
        #expect(moves("/Users/me/Downloads/EleDock.app"))
        #expect(moves("/Volumes/EleDock/EleDock.app"))
        #expect(moves("/Users/other/Applications/EleDock.app"))
    }

    @Test func sameFileAsInstalledDoesNotMove() {
        #expect(!moves("/Users/me/Desktop/EleDock.app", sameFile: [user]))
    }

    @Test func otherInstallPathsExcludeKeptInstall() {
        #expect(otherInstallPaths(installPaths, keeping: system, sameFilePaths: [system]) == [user])
        #expect(otherInstallPaths(installPaths, keeping: user, sameFilePaths: []) == [system])
    }

    @Test func otherInstallPathsExcludeSameFileAsKeptInstall() {
        #expect(otherInstallPaths(installPaths, keeping: system, sameFilePaths: [system, user]).isEmpty)
    }

    @Test func everyInstallPathIsOtherForBundleOutside() {
        #expect(
            otherInstallPaths(installPaths, keeping: "/Users/me/Downloads/EleDock.app", sameFilePaths: [])
                == installPaths)
    }
}
