import AppKit
import Sparkle

/// Sparkle 업데이터를 관리한다.
final class UpdateController {
    /// 메뉴 "업데이트 확인" 의 target.
    let standardController: SPUStandardUpdaterController
    private let userDriverDelegate: ScheduledUpdateActivator
    private let hasFeed: Bool
    private var canCheckObservation: NSKeyValueObservation?

    /// 시작한 업데이터.
    var updater: SPUUpdater? { hasFeed ? standardController.updater : nil }

    init(state: AppState) {
        let hasFeed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
        let userDriverDelegate = ScheduledUpdateActivator()
        self.hasFeed = hasFeed
        self.userDriverDelegate = userDriverDelegate
        standardController = SPUStandardUpdaterController(
            startingUpdater: hasFeed, updaterDelegate: nil, userDriverDelegate: userDriverDelegate)
        if hasFeed {
            canCheckObservation = standardController.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) {
                updater, _ in
                if Thread.isMainThread {
                    MainActor.assumeIsolated { state.canCheckForUpdates = updater.canCheckForUpdates }
                } else {
                    DispatchQueue.main.async { state.canCheckForUpdates = updater.canCheckForUpdates }
                }
            }
        }
    }
}

private final class ScheduledUpdateActivator: NSObject, @preconcurrency SPUStandardUserDriverDelegate {
    // 예약 확인으로 찾은 업데이트 창을 앞으로 가져온다.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        guard !state.userInitiated else { return }
        NSApp.activate(ignoringOtherApps: true)
    }
}
