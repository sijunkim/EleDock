import CoreGraphics

/// 오버레이 키프레임과 실제 창 축소에 쓰는 사각형 계산.
public enum FrameInterpolation {
    /// 앱이 축소를 무시한 것으로 보는 면적 비율.
    public static let ignoredAreaRatio: CGFloat = 0.15
    /// 앱이 축소를 무시한 것으로 보는 한 변 길이.
    public static let ignoredSideLength: CGFloat = 200

    /// `progress` 만큼 `from` 에서 `to` 로 옮긴 사각형.
    public static func interpolate(from: CGRect, to: CGRect, progress: Double) -> CGRect {
        let p = CGFloat(progress)
        func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a * (1 - p) + b * p }
        let from = from.standardized
        let to = to.standardized
        return CGRect(
            x: lerp(from.minX, to.minX), y: lerp(from.minY, to.minY),
            width: max(0, lerp(from.width, to.width)), height: max(0, lerp(from.height, to.height)))
    }

    /// `curve` 로 `count` 개 샘플링한 키프레임.
    public static func keyframes(from: CGRect, to: CGRect, curve: AnimationCurve, count: Int) -> [CGRect] {
        AnimationTiming.sampleTimes(count: count).map { interpolate(from: from, to: to, progress: curve.value(at: $0)) }
    }

    /// AX 좌표와 AppKit 좌표를 서로 바꾼다.
    public static func flipped(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.minY - rect.height, width: rect.width, height: rect.height)
    }

    /// 비율을 유지해 `box` 가운데에 들어가는 가장 큰 사각형.
    public static func aspectFit(_ size: CGSize, into box: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return CGRect(x: box.midX, y: box.midY, width: 0, height: 0) }
        let scale = min(box.width / size.width, box.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(
            x: box.midX - fitted.width / 2, y: box.midY - fitted.height / 2, width: fitted.width,
            height: fitted.height)
    }

    /// 앱이 창 축소를 무시했는지 판정한다.
    public static func shrinkWasIgnored(original: CGRect, actual: CGRect) -> Bool {
        let originalArea = original.width * original.height
        let actualArea = actual.width * actual.height
        return actualArea > originalArea * ignoredAreaRatio || max(actual.width, actual.height) > ignoredSideLength
    }

    /// 긴 변이 `maxLength` 를 넘지 않게 비율을 유지해 줄인 크기.
    public static func downscaled(_ size: CGSize, maxLength: CGFloat) -> CGSize {
        let longest = max(size.width, size.height)
        guard longest > maxLength else { return size }
        let scale = maxLength / longest
        return CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
    }
}
