import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    let onBack: () -> Void

    private var descriptors: [ProviderDescriptor] { UsageProviderRegistry.descriptors }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BackButton(title: "Back", action: onBack)

            generalCard
            providersCard
        }
    }

    private var generalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("General").sectionTitle()

            VStack(spacing: 10) {
                HStack {
                    Text("Refresh interval")
                        .font(.system(size: 12.5, weight: .medium))
                    Spacer()
                    Picker("", selection: $settings.refreshInterval) {
                        ForEach(RefreshInterval.allCases) { interval in
                            Text(interval.title).tag(interval)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }

                Divider()

                Toggle(isOn: $settings.launchAtLogin) {
                    Text("Launch at login")
                        .font(.system(size: 12.5, weight: .medium))
                }
                .toggleStyle(.switch)
            }
        }
        .padding(12)
        .background(appCardBackground)
    }

    private var providersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Providers").sectionTitle()

            VStack(spacing: 10) {
                ForEach(Array(descriptors.enumerated()), id: \.element.id) { index, provider in
                    if index > 0 { Divider() }
                    providerRow(provider)
                }
            }
        }
        .padding(12)
        .background(appCardBackground)
    }

    private func providerRow(_ provider: ProviderDescriptor) -> some View {
        HStack(spacing: 10) {
            ProviderIcon(symbol: provider.symbolName, accent: .providerAccent(provider.accentName))
            Text(provider.name)
                .font(.system(size: 12.5, weight: .medium))
            Spacer()
            Toggle("", isOn: Binding(
                get: { settings.isProviderEnabled(provider.id) },
                set: { settings.setProvider(provider.id, enabled: $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
    }
}
