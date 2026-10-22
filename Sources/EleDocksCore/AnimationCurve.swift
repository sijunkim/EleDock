import Foundation

/// 직접 그리는 최소화·복원 애니메이션의 진행 곡선.
public enum AnimationCurve: String, CaseIterable, Sendable {
    /// 점점 빠르게.
    case easeIn
    /// 점점 느리게.
    case easeOut
    /// 일정하게.
    case linear
    /// 부드럽게.
    case easeInOut
    /// 튕기듯.
    case spring

    /// 저장값이 없을 때 쓰는 곡선.
    public static let defaultValue: AnimationCurve = .easeOut

    /// spring 의 목표 초과 세기.
    private static let springOvershoot = 1.0

    /// 저장소에서 읽은 값으로 만든다.
    public init(storedValue: Any?) {
        self = (storedValue as? String).flatMap(Self.init(rawValue:)) ?? Self.defaultValue
    }

    /// 시간 진행률 `t` 에서의 위치 진행률.
    public func value(at t: Double) -> Double {
        let t = min(max(t, 0), 1)
        switch self {
        case .easeIn:
            return t * t * t
        case .easeOut:
            let rest = 1 - t
            return 1 - rest * rest * rest
        case .linear:
            return t
        case .easeInOut:
            if t < 0.5 { return 4 * t * t * t }
            let rest = 2 - 2 * t
            return 1 - rest * rest * rest / 2
        case .spring:
            let rest = t - 1
            return 1 + (Self.springOvershoot + 1) * rest * rest * rest + Self.springOvershoot * rest * rest
        }
    }
}
