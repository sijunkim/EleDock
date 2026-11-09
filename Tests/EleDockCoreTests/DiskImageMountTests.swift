import Testing

@testable import EleDockCore

struct DiskImageMountTests {
    private func image(_ path: String, mounts: [String?]) -> [String: Any] {
        let entities: [[String: Any]] = mounts.map { mount in
            var entity: [String: Any] = ["dev-entry": "/dev/disk9s1"]
            entity["mount-point"] = mount
            return entity
        }
        return ["image-path": path, "system-entities": entities]
    }

    @Test func collectsMountedEntitiesOnly() {
        let info: [String: Any] = [
            "images": [image("/Users/me/Downloads/EleDock.dmg", mounts: [nil, "/Volumes/EleDock"])]
        ]
        #expect(
            DiskImageMount.list(hdiutilInfo: info) == [
                DiskImageMount(imagePath: "/Users/me/Downloads/EleDock.dmg", mountPoint: "/Volumes/EleDock")
            ])
    }

    @Test func collectsEveryImage() {
        let info: [String: Any] = [
            "images": [
                image("/a.dmg", mounts: ["/Volumes/A"]),
                image("/b.dmg", mounts: [nil]),
                image("/c.dmg", mounts: ["/Volumes/C"]),
            ]
        ]
        #expect(DiskImageMount.list(hdiutilInfo: info).map(\.mountPoint) == ["/Volumes/A", "/Volumes/C"])
    }

    @Test func malformedInfoIsEmpty() {
        #expect(DiskImageMount.list(hdiutilInfo: [:]).isEmpty)
        #expect(DiskImageMount.list(hdiutilInfo: ["images": "x"]).isEmpty)
        #expect(DiskImageMount.list(hdiutilInfo: ["images": [["system-entities": []]]]).isEmpty)
    }

    @Test func containsPathInsideVolume() {
        let mount = DiskImageMount(imagePath: "/a.dmg", mountPoint: "/Volumes/EleDock")
        #expect(mount.contains(path: "/Volumes/EleDock/EleDock.app"))
        #expect(!mount.contains(path: "/Volumes/EleDock 1/EleDock.app"))
        #expect(!mount.contains(path: "/Applications/EleDock.app"))
    }
}
