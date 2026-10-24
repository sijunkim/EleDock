/// 붙어 있는 디스크 이미지의 마운트 지점.
public struct DiskImageMount: Equatable {
    /// 이미지 파일 경로.
    public let imagePath: String
    /// 마운트 지점 경로.
    public let mountPoint: String

    /// `hdiutil info -plist` 딕셔너리에서 마운트 지점을 모은다.
    public static func list(hdiutilInfo: [String: Any]) -> [DiskImageMount] {
        guard let images = hdiutilInfo["images"] as? [[String: Any]] else { return [] }
        return images.flatMap { image -> [DiskImageMount] in
            guard let path = image["image-path"] as? String,
                let entities = image["system-entities"] as? [[String: Any]]
            else { return [] }
            return entities.compactMap { entity in
                (entity["mount-point"] as? String).map { DiskImageMount(imagePath: path, mountPoint: $0) }
            }
        }
    }

    /// 경로가 이 볼륨 안에 있다.
    public func contains(path: String) -> Bool {
        path.hasPrefix(mountPoint + "/")
    }
}
