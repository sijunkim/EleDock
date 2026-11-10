/// 정규 설치 경로 중 남길 번들 `path` 와 같은 설치본이 아닌 경로를 돌려준다.
public func otherInstallPaths(_ installPaths: [String], keeping path: String, sameFilePaths: Set<String>) -> [String] {
    installPaths.filter { $0 != path && !sameFilePaths.contains($0) }
}

/// 번들이 정규 설치 경로가 아니어서 정규 경로로 설치해야 하는지 판정한다.
public func needsMove(path: String, installPaths: [String], sameFilePaths: Set<String>) -> Bool {
    otherInstallPaths(installPaths, keeping: path, sameFilePaths: sameFilePaths).count == installPaths.count
}
