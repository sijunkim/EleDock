/// 전역 단축키를 등록해 둘지 정한다.
public enum HotKeyPolicy {
    /// 전역 단축키를 등록할지 판정한다.
    public static func shouldRegister(
        trusted: Bool, enabled: Bool, recording: Bool, frontmostExcluded: Bool, holding: Bool
    ) -> Bool {
        trusted && enabled && !recording && (holding || !frontmostExcluded)
    }
}
