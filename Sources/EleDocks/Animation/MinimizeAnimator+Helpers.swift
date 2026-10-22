import ApplicationServices
import EleDocksCore

/// 조회·저장 frame 정리·Dock 칸·키프레임 헬퍼.
extension MinimizeAnimator {
    /// 최소화 직전 저장값 정리 결과.
    enum Settlement {
        /// 저장값을 되돌렸다.
        case clear
        /// 이미 최소화됐거나 앱이 거부했다.
        case plain
        /// 아직 확정되지 않았다.
        case busy
    }

    func probe(_ window: AXUIElement, before deadline: AXDeadline) throws(AccessibilityError) -> CGRect? {
        let frame = try window.frame(before: deadline)
        guard try !deadline.run(window, { () throws(AccessibilityError) in try window.isFullScreen }),
            try !window.hasSheet(before: deadline)
        else { return nil }
        return frame
    }

    // 최소화되지 않은 채 남은 저장값을 처리한다.
    func settleSavedFrame(_ window: AXUIElement, restoring: Bool) -> Settlement {
        switch window.withMessagingTimeout(WindowTracker.callTimeout, { window.minimizedState }) {
        case nil:
            if !restoring, !savedFrames.isPutBackScheduled(window) {
                savedFrames.schedulePutBack(window, after: 0, requiresUnminimized: true)
            }
            return .busy
        case true?:
            return .plain
        case false?:
            let outcome = restoring ? savedFrames.putBackOnce(window) : savedFrames.putBackSoon(window)
            switch outcome {
            case .done: return .clear
            case .busy, .cancelled: return .busy
            case .refused: return .plain
            }
        }
    }

    // Dock 칸 수를 센다.
    func countingSlot(_ result: RepeatPolicy.Attempt) -> RepeatPolicy.Attempt {
        if result == .success || result == .busy { slotsSinceLayout += 1 }
        return result
    }

    func keyframes(from: CGRect, to: CGRect) -> [CGRect] {
        let count = AnimationTiming.sampleCount(duration: settings.animationDuration)
        return FrameInterpolation.keyframes(from: from, to: to, curve: settings.animationCurve, count: count)
    }
}
