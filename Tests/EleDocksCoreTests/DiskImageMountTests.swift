import Testing

@testable import EleDocksCore

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
            "images": [image("/Users/me/Downloads/EleDocks.dmg", mounts: [nil, "/Volumes/EleDocks"])]
        ]
        #expect(
            DiskImageMount.list(hdiutilInfo: info) == [
                DiskImageMount(imagePath: "/Users/me/Downloads/EleDocks.dmg", mountPoint: "/Volumes/EleDocks")
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
        let mount = DiskImageMount(imagePath: "/a.dmg", mountPoint: "/Volumes/EleDocks")
        #expect(mount.contains(path: "/Volumes/EleDocks/EleDocks.app"))
        #expect(!mount.contains(path: "/Volumes/EleDocks 1/EleDocks.app"))
        #expect(!mount.contains(path: "/Applications/EleDocks.app"))
    }
}
