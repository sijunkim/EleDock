import AppKit

/// 이 프로세스가 끝난 뒤 앱을 다시 연다.
enum Relauncher {
    /// 이 프로세스 종료 뒤 `bundle` 을 여는 셸을 띄운다.
    static func openAfterExit(_ bundle: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c", "while /bin/kill -0 \"$1\" 2>/dev/null; do /bin/sleep 0.1; done; /usr/bin/open \"$2\"",
            "sh", String(getpid()), bundle.path,
        ]
        return (try? process.run()) != nil
    }

    /// 앱을 다시 열도록 하고 종료한다.
    static func relaunchAndTerminate() {
        guard openAfterExit(Bundle.main.bundleURL) else { return }
        NSApp.terminate(nil)
    }
}
