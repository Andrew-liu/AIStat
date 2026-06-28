import SwiftUI

struct AwakePanelView: View {
    @ObservedObject var awakeController: AwakeController
    /// 当前品牌强调色（跟随设置）。
    var accent: Color = .providerAccent("purple")

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                Button {
                    awakeController.toggleDefault()
                } label: {
                    ProviderIcon(
                        symbol: awakeController.isKeepingAwake ? "cup.and.saucer.fill" : "moon.zzz.fill",
                        accent: awakeController.isKeepingAwake ? .providerAccent("orange") : .secondary
                    )
                }
                .buttonStyle(.plain)
                .help(Text(awakeController.isKeepingAwake ? "awake.disable" : "awake.enable"))

                VStack(alignment: .leading, spacing: 1) {
                    Text("awake.title")
                        .font(.system(size: 12.5, weight: .semibold))
                    Text(awakeController.statusText)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(awakeController.detailText)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { awakeController.isKeepingAwake },
                    set: { enabled in awakeController.setMode(enabled ? .forever : .off) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
            }

            HStack(spacing: 5) {
                ForEach(AwakeMode.allCases) { mode in
                    Button {
                        awakeController.setMode(mode)
                    } label: {
                        Text(mode.title)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(awakeController.mode == mode ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background {
                                Capsule()
                                    .fill(awakeController.mode == mode ? accent : .secondary.opacity(0.10))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(appCardBackground)
    }
}
