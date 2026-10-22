/// 판정 회차 하나에서 응답 지연이 난 그룹.
public struct BusyGroups<Group: Equatable> {
    private var busy: [Group] = []

    /// 빈 상태로 만든다.
    public init() {}

    /// `group` 의 값을 읽고 응답 지연을 기록한다.
    public mutating func read<Value, Failure: Error>(
        _ group: Group, isBusy: (Failure) -> Bool, _ read: () throws(Failure) -> Value
    ) -> Value? {
        guard !busy.contains(group) else { return nil }
        do {
            return try read()
        } catch {
            if isBusy(error) { busy.append(group) }
            return nil
        }
    }
}
