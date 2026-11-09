/// 실행 중인 앱 번들이 놓인 위치.
public enum InstallLocation: Equatable, Sendable {
    /// /Applications 안.
    case applications
    /// ~/Applications 안.
    case userApplications
    /// 응용 프로그램 폴더의 앱과 같은 파일.
    case sameFileAsInstalled
    /// 그 밖의 위치.
    case other

    /// 번들 경로로 분류한다.
    public init(path: String, homeDirectory: String, isSameFileAsInstalled: Bool) {
        if path.hasPrefix("/Applications/") {
            self = .applications
        } else if path.hasPrefix(homeDirectory + "/Applications/") {
            self = .userApplications
        } else if isSameFileAsInstalled {
            self = .sameFileAsInstalled
        } else {
            self = .other
        }
    }

    /// 응용 프로그램 폴더로 옮기기를 권하는 위치다.
    public var needsMove: Bool { self == .other }
}
