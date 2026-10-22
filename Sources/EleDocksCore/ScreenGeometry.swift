import CoreGraphics

/// 창이 어느 화면에 있는지 정한다.
public enum ScreenGeometry {
    /// `rect` 와 가장 많이 겹치는 화면.
    public static func screen(for rect: CGRect, in screens: [CGRect]) -> CGRect? {
        var best: (screen: CGRect, area: CGFloat)?
        for screen in screens {
            let area = overlapArea(screen, rect)
            if area > (best?.area ?? 0) { best = (screen, area) }
        }
        return best?.screen
    }

    /// `point` 를 포함하는 첫 화면.
    public static func screen(containing point: CGPoint, in screens: [CGRect]) -> CGRect? {
        screens.first { $0.contains(point) }
    }

    private static func overlapArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let overlap = a.intersection(b)
        return overlap.isNull ? 0 : overlap.width * overlap.height
    }
}
