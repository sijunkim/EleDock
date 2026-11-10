import AppKit
import Sparkle

/// Sparkle 업데이터를 관리한다.
final class UpdateController {
    /// 메뉴 "업데이트 확인" 의 target.
    let standardController: SPUStandardUpdaterController
    /// 시작한 업데이터. 피드가 없으면 nil.
    let updater: SPUUpdater?
    private let userDriverDelegate = ScheduledUpdateActivator()

    init(state: AppState) {
        let hasFeed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
        standardController = SPUStandardUpdaterController(
            startingUpdater: hasFeed, updaterDelegate: nil, userDriverDelegate: userDriverDelegate)
        updater = hasFeed ? standardController.updater : nil
        updater?.publisher(for: \.canCheckForUpdates).assign(to: &state.$canCheckForUpdates)
    }
}

/// 예약 확인으로 찾은 업데이트 창을 앞으로 가져온다.
private final class ScheduledUpdateActivator: NSObject, @preconcurrency SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        guard !state.userInitiated else { return }
        NSApp.activate(ignoringOtherApps: true)
    }
}
