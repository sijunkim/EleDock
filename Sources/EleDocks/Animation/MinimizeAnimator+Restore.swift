import AppKit
import ApplicationServices
import EleDocksCore

/// 복원 흐름.
extension MinimizeAnimator {
    /// 최소화된 창을 Dock 타일에서 원래 자리로 그리며 복원한다.
    func restore(_ entry: WindowEntry, plain: Plain) -> RepeatPolicy.Attempt {
        let window = entry.window
        if let job = jobs[window] {
            guard job.kind == .minimize else { return .failure }
            cancel(job)
        }
        guard let image = snapshots.image(for: window), !savedFrames.isLocked(entry.pid),
            AnimationAdmission.evaluate(activeJobs: jobs.count, pendingCaptures: 0, capturing: false) == .accept
        else { return plain() }
        let original: CGRect
        do {
            original = try savedFrames.original(ofMinimized: window)
        } catch .cannotComplete {
            return .wait
        } catch {
            return plain()
        }
        guard let layout = dockLayout else { return plain() }
        if NSScreen.screensHaveSeparateSpaces, DockLocator.screenFrame(for: original) != layout.screen {
            return plain()
        }

        let appName = NSRunningApplication(processIdentifier: entry.pid)?.localizedName
        let tile = DockGeometry.restoreSource(in: layout, windowTitle: window.title, appName: appName)
        let target = FrameInterpolation.aspectFit(original.size, into: tile)
        let overlay = OverlayWindow(image: image, frames: keyframes(from: target, to: original))
        overlay.show(opacity: 0)
        let shrunk = savedFrames.shrink(
            window, pid: entry.pid, from: original, to: DockGeometry.shrinkTarget(target, in: layout))
        guard shrunk == .done else {
            overlay.close()
            savedFrames.putBackSoon(window)
            return shrunk == .busy ? .wait : plain()
        }
        let result = plain()
        guard result == .success else {
            overlay.close()
            savedFrames.putBackSoon(window)
            return result
        }
        snapshots.remove(window)
        let job = AnimationJob(kind: .restore, window: window, pid: entry.pid, overlay: overlay)
        jobs[window] = job
        let duration = settings.animationDuration
        overlay.animate(duration: duration, opacity: AnimationTiming.restoreOpacity) { [weak self] in
            self?.finishRestore(job, after: max(AnimationTiming.unresponsiveTime - duration, 0))
        }
        return .success
    }

    // 복원 애니메이션 뒤 원래 frame 을 되돌리고 오버레이를 걷는다.
    private func finishRestore(_ job: AnimationJob, after delay: Double) {
        guard jobs[job.window] === job else { return }
        job.stage = .settling
        Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !job.isCancelled else { return }
            let outcome = await savedFrames.putBack(job.window) { job.isCancelled }
            guard !job.isCancelled else { return }
            if outcome == .busy {
                savedFrames.schedulePutBack(
                    job.window, after: AnimationTiming.unresponsiveTime, requiresUnminimized: true)
            }
            job.overlay?.fadeOut(
                after: AnimationTiming.restoreFadeOutDelay, duration: AnimationTiming.restoreFadeOutDuration
            ) { self.finish(job) }
        }
    }
}
