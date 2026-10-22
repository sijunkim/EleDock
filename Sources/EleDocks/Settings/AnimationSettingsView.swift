import AppKit
import EleDocksCore
import SwiftUI

/// 애니메이션 탭: 직접 그리는 최소화·복원 애니메이션의 켜기·속도·효과와 화면 기록 권한.
struct AnimationSettingsView: View {
    @ObservedObject var settings: AppSettings
    @StateObject private var model: AnimationSettingsModel

    init(settings: AppSettings, permission: ScreenRecordingPermission) {
        self.settings = settings
        _model = StateObject(wrappedValue: AnimationSettingsModel(permission: permission))
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $settings.animationEnabled) {
                    Text(L("animation.enabled")).dimmed(!ScreenRecordingPermission.isSupported)
                }
                Group {
                    LabeledContent {
                        HStack {
                            Slider(
                                value: speed,
                                in: AnimationTiming.minimumDuration...AnimationTiming.maximumDuration
                            ) {
                                Text(L("animation.speed"))
                            } minimumValueLabel: {
                                Text(L("animation.speed.slow"))
                            } maximumValueLabel: {
                                Text(L("animation.speed.fast"))
                            }
                            .labelsHidden()
                            .accessibilityValue(Text(durationText))
                            Text(durationText)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    } label: {
                        Text(L("animation.speed")).dimmed(optionsDisabled)
                    }
                    Picker(selection: $settings.animationCurve) {
                        ForEach(AnimationCurve.allCases, id: \.self) { curve in
                            Text(Self.name(of: curve)).tag(curve)
                        }
                    } label: {
                        Text(L("animation.curve")).dimmed(optionsDisabled)
                    }
                }
                .disabled(!settings.animationEnabled)
            } footer: {
                SectionFooter(
                    ScreenRecordingPermission.isSupported
                        ? String(format: L("animation.help"), Self.permissionName) : L("animation.unsupported"))
            }
            if ScreenRecordingPermission.isSupported {
                Section {
                    LabeledContent(Self.permissionName) {
                        HStack {
                            Text(L(model.isGranted ? "animation.permission.granted" : "animation.permission.required"))
                                .foregroundStyle(.secondary)
                            if !model.isGranted {
                                Button(L("animation.permission.request"), action: request)
                            }
                        }
                    }
                    if model.needsRelaunch {
                        HStack {
                            Text(L("animation.permission.restart")).foregroundStyle(.secondary)
                            Spacer()
                            Button(L("settings.relaunch"), action: Relauncher.relaunchAndTerminate)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .disabled(!ScreenRecordingPermission.isSupported)
        .frame(width: SettingsLayout.width, height: height)
        .onAppear(perform: model.refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refresh()
        }
    }

    /// 속도 슬라이더 위치.
    private var speed: Binding<Double> {
        Binding(
            get: { AnimationTiming.sliderPosition(duration: settings.animationDuration) },
            set: { settings.animationDuration = AnimationTiming.duration(sliderPosition: $0) })
    }

    /// 속도·효과를 바꿀 수 없는 상태.
    private var optionsDisabled: Bool {
        !settings.animationEnabled || !ScreenRecordingPermission.isSupported
    }

    private var height: CGFloat {
        guard ScreenRecordingPermission.isSupported else { return SettingsLayout.animationUnsupportedHeight }
        return SettingsLayout.animationHeight + (model.needsRelaunch ? SettingsLayout.relaunchRowHeight : 0)
    }

    private var durationText: String {
        String(
            format: L("animation.duration"),
            Self.durationFormatter.string(from: NSNumber(value: settings.animationDuration)) ?? "")
    }

    /// 시스템 설정의 화면 기록 권한 패널 이름.
    private static var permissionName: String {
        if #available(macOS 15, *) { L("animation.permission.screenAudio") } else { L("animation.permission.screen") }
    }

    /// 지속 시간 표시용 숫자 포맷터.
    private static let durationFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private func request() {
        model.request()
    }

    private static func name(of curve: AnimationCurve) -> String {
        switch curve {
        case .easeIn: L("animation.curve.easeIn")
        case .easeOut: L("animation.curve.easeOut")
        case .linear: L("animation.curve.linear")
        case .easeInOut: L("animation.curve.easeInOut")
        case .spring: L("animation.curve.spring")
        }
    }
}

// 애니메이션 탭의 화면 상태.
private final class AnimationSettingsModel: ObservableObject {
    private let permission: ScreenRecordingPermission
    @Published private(set) var isGranted = false
    /// 권한을 요청했지만 아직 허용으로 보이지 않는다.
    @Published private(set) var needsRelaunch = false

    init(permission: ScreenRecordingPermission) {
        self.permission = permission
    }

    func refresh() {
        isGranted = permission.isGranted
        needsRelaunch = permission.hasRequested && !isGranted
    }

    func request() {
        permission.request()
        refresh()
    }
}
