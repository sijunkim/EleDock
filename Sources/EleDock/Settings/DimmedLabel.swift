import SwiftUI

extension View {
    /// 비활성 컨트롤의 레이블을 흐리게 한다.
    @ViewBuilder
    func dimmed(_ isDimmed: Bool) -> some View {
        if isDimmed {
            foregroundStyle(.secondary)
        } else {
            self
        }
    }
}
