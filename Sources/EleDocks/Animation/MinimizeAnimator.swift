import AppKit
import ApplicationServices
import EleDocksCore

/// 직접 그리는 최소화·복원 애니메이션을 창별 작업으로 조정한다.
final class MinimizeAnimator {
    /// 기존 최소화·복원 set 경로.
    typealias Plain = () -> RepeatPolicy.Attempt

    let settings: AppSettings
    private let permission: ScreenRecordingPermission
    var jobs: [AXUIElement: AnimationJob] = [:]
    let savedFrames = SavedFrames()
    var snapshots = SnapshotCache()
    /// 캡처부터 kAXMinimized 까지를 잇는 앞 작업.
    private var captureChain: Task<Void, Never>?
    /// 이번 동작에서 읽은 Dock 상태.
    var dockLayout: DockLayout?
    /// 이번 동작에서 최소화를 보낸 창 수.
    var slotsSinceLayout = 0

    init(settings: AppSettings, permission: ScreenRecordingPermission) {
        self.settings = settings
        self.permission = permission
    }

    /// 직접 그리는 애니메이션을 쓰는지.
    var isActive: Bool {
        AnimationAdmission.isActive(
            enabled: settings.animationEnabled, isSupported: ScreenRecordingPermission.isSupported,
            isGranted: permission.isGranted)
    }

    /// 최소화 작업이 진행 중이다.
    func isMinimizing(_ window: AXUIElement) -> Bool {
        jobs[window]?.kind == .minimize
    }

    /// 창 하나를 직접 그리는 애니메이션으로 최소화한다.
    func minimize(_ entry: WindowEntry, plain: Plain) -> RepeatPolicy.Attempt {
        let window = entry.window
        let restoring = jobs[window]
        if let restoring {
            guard restoring.kind == .restore else { return .failure }
            guard restoring.stage == .settling else { return .wait }
        }
        let settlement =
            savedFrames.contains(window) ? settleSavedFrame(window, restoring: restoring != nil) : .clear
        if settlement == .busy { return .wait }
        if let restoring {
            restoring.stage = .cancelled
            finish(restoring)
        }
        if settlement == .plain { return countingSlot(plain()) }
        guard #available(macOS 14, *), !savedFrames.isLocked(entry.pid) else { return countingSlot(plain()) }
        switch jobs.values.minimizeAdmission {
        case .animate: break
        case .wait: return .wait
        case .plain: return countingSlot(plain())
        }
        guard let layout = dockLayout else { return countingSlot(plain()) }
        let deadline = AXDeadline(seconds: AnimationTiming.axCallTimeout)
        guard let frame = try? probe(window, before: deadline) else { return countingSlot(plain()) }
        if NSScreen.screensHaveSeparateSpaces, DockLocator.screenFrame(for: frame) != layout.screen {
            return countingSlot(plain())
        }

        let title = window.title(before: deadline)
        let appName = NSRunningApplication(processIdentifier: entry.pid)?.localizedName
        let tile = DockGeometry.minimizeDestination(in: layout, appName: appName, pendingCount: slotsSinceLayout)
        let target = FrameInterpolation.aspectFit(frame.size, into: tile)
        let shrunk = DockGeometry.shrinkTarget(target, in: layout)
        let job = AnimationJob(kind: .minimize, window: window, pid: entry.pid)
        jobs[window] = job
        slotsSinceLayout += 1
        let previous = captureChain
        captureChain = Task {
            await previous?.value
            await self.runMinimize(job, frame: frame, target: target, shrunk: shrunk, title: title)
        }
        return .success
    }

    /// 아직 시스템 최소화를 보내지 않은 가장 최근 최소화 작업을 취소하고 그 창을 돌려준다.
    func takeLatestUnsentMinimize() -> WindowEntry? {
        guard
            let job = jobs.values.filter({ $0.kind == .minimize && $0.isUnsentMinimize })
                .max(by: { $0.order < $1.order })
        else { return nil }
        cancel(job)
        return WindowEntry(pid: job.pid, window: job.window)
    }

    /// 창이 최소화됐다.
    func windowMinimized(_ window: AXUIElement) {
        guard jobs[window] == nil, savedFrames.contains(window), !savedFrames.isPutBackScheduled(window) else { return }
        savedFrames.schedulePutBack(window, after: AnimationTiming.unresponsiveTime)
    }

    /// 창이 복원됐거나 사라졌다.
    func windowGone(_ window: AXUIElement) {
        snapshots.remove(window)
        if let job = jobs[window] {
            guard job.kind == .minimize else { return }
            cancel(job)
        }
        guard savedFrames.contains(window) else { return }
        savedFrames.schedulePutBack(window, after: AnimationTiming.unresponsiveTime)
    }

    /// 앱이 종료됐다. 그 앱의 작업·스냅숏·저장 frame 을 버린다.
    func forget(pid: pid_t) {
        for job in jobs.values where job.pid == pid {
            job.stage = .cancelled
            finish(job)
        }
        snapshots.removeAll(pid: pid)
        savedFrames.removeAll(pid: pid)
    }

    /// 동작을 시작한다.
    func beginRepeat(repeats: Bool) {
        savedFrames.isRepeating = repeats
        dockLayout = isActive ? DockLocator.layout() : nil
        slotsSinceLayout = 0
    }

    /// 연속 동작이 끝났다.
    func endRepeat() {
        savedFrames.isRepeating = false
        dockLayout = nil
    }

    /// 작업을 모두 멈추고 오버레이를 걷는다.
    func cancelAll() {
        for job in jobs.values {
            job.stage = .cancelled
            job.overlay?.close()
        }
        jobs = [:]
    }

    /// 최소화되지 않은 채 줄어 있는 창을 되돌린다.
    func putBackUnminimizedFrames() {
        savedFrames.putBackUnminimized()
    }

    /// 작업을 모두 멈추고 줄여 둔 창 frame 을 되돌린다.
    func restoreAllSavedFrames() {
        cancelAll()
        savedFrames.putBackAll()
    }

    // MARK: - 최소화 작업

    @available(macOS 14, *)
    private func runMinimize(
        _ job: AnimationJob, frame: CGRect, target: CGRect, shrunk shrinkTarget: CGRect, title: String?
    ) async {
        let window = job.window
        let image =
            job.isCancelled
            ? nil
            : await WindowSnapshotter.capture(
                pid: job.pid, frame: frame, title: title, timeout: AnimationTiming.captureTimeout)
        guard !job.isCancelled else { return }
        job.stage = .preparing
        guard let image else { return await minimizePlainly(job) }

        let overlay = OverlayWindow(image: image, frames: keyframes(from: frame, to: target))
        job.overlay = overlay
        overlay.show(opacity: 1)
        guard await yieldWhileRepeating(job) else { return }
        let shrunk = await shrinkWaiting(job, from: frame, to: shrinkTarget)
        guard !job.isCancelled else { return }
        guard shrunk else {
            guard await yieldWhileRepeating(job) else { return }
            revert(job)
            return await minimizePlainly(job)
        }
        overlay.animate(duration: settings.animationDuration, opacity: AnimationTiming.minimizeOpacity) {
            [weak self] in
            if job.stage == .minimized { self?.finish(job) } else { overlay.close() }
        }
        guard await yieldWhileRepeating(job) else { return }
        let minimized = await job.sendMinimize(yield: { await yieldWhileRepeating(job) })
        guard !job.isCancelled else { return }
        guard minimized else {
            guard await yieldWhileRepeating(job) else { return }
            revert(job)
            return finish(job)
        }
        job.stage = .minimized
        snapshots.insert(image, for: window, pid: job.pid)
        savedFrames.schedulePutBack(window, after: AnimationTiming.unresponsiveTime)
        if overlay.isClosed { finish(job) }
    }

    // 오버레이를 걷고 실제 창 frame 을 되돌린다.
    private func revert(_ job: AnimationJob) {
        job.overlay?.close()
        savedFrames.putBackSoon(job.window)
    }

    // 실제 창 줄이기를 다시 시도하며 기다린다.
    @available(macOS 14, *)
    private func shrinkWaiting(_ job: AnimationJob, from frame: CGRect, to target: CGRect) async -> Bool {
        let start = ContinuousClock.now
        while true {
            switch savedFrames.shrink(job.window, pid: job.pid, from: frame, to: target) {
            case .done:
                return true
            case .busy:
                guard ShrinkPolicy.canRetry(waited: .now - start) else { return false }
                try? await Task.sleep(for: .seconds(AnimationTiming.shrinkRetryInterval))
                guard !job.isCancelled else { return false }
                guard ShrinkPolicy.canAttempt(waited: .now - start) else { return false }
            default:
                return false
            }
        }
    }

    // 스냅숏 없이 기본 동작으로 최소화한다.
    private func minimizePlainly(_ job: AnimationJob) async {
        _ = await job.sendMinimize(yield: { await yieldWhileRepeating(job) })
        finish(job)
    }

    // 다음 단계 전에 메인 스레드를 넘긴다.
    private func yieldWhileRepeating(_ job: AnimationJob) async -> Bool {
        if savedFrames.isRepeating { try? await Task.sleep(for: .seconds(AnimationTiming.repeatHandoffDelay)) }
        return !job.isCancelled
    }

    // MARK: - 공통

    // 오버레이를 걷고 작업을 뺀다.
    func cancel(_ job: AnimationJob) {
        let minimized = job.stage == .minimized
        job.stage = .cancelled
        finish(job)
        guard job.kind == .minimize, !minimized else { return }
        snapshots.remove(job.window)
        savedFrames.putBackSoon(job.window)
    }

    func finish(_ job: AnimationJob) {
        job.overlay?.close()
        if jobs[job.window] === job { jobs[job.window] = nil }
    }
}
