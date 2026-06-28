import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    let onBack: () -> Void

    private var descriptors: [ProviderDescriptor] { UsageProviderRegistry.descriptors }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BackButton(title: LocalizedStringKey("nav.back"), action: onBack)

            generalCard
            appearanceCard
            notificationCard
            providersCard
        }
    }

    // MARK: General

    private var generalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("settings.general").sectionTitle()

            VStack(spacing: 10) {
                HStack {
                    Text("settings.refreshInterval")
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
                    Text("settings.launchAtLogin")
                        .font(.system(size: 12.5, weight: .medium))
                }
                .toggleStyle(.switch)
            }
        }
        .padding(12)
        .background(appCardBackground)
    }

    // MARK: Appearance

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("settings.appearance").sectionTitle()

            VStack(spacing: 10) {
                HStack {
                    Text("settings.language")
                        .font(.system(size: 12.5, weight: .medium))
                    Spacer()
                    Picker("", selection: $settings.language) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(LocalizedStringKey(lang.titleKey)).tag(lang)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }

                // 语言更改需重启生效，给出提示。
                Text("settings.languageRestartHint")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                HStack {
                    Text("settings.theme")
                        .font(.system(size: 12.5, weight: .medium))
                    Spacer()
                    Picker("", selection: $settings.appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(LocalizedStringKey(mode.titleKey)).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }

                Divider()

                HStack {
                    Text("settings.accentColor")
                        .font(.system(size: 12.5, weight: .medium))
                    Spacer()
                    accentSwatches
                }
            }
        }
        .padding(12)
        .background(appCardBackground)
    }

    private var accentSwatches: some View {
        HStack(spacing: 8) {
            ForEach(AccentPreset.allCases) { preset in
                let color = Color.providerAccent(preset.accentName)
                Circle()
                    .fill(color)
                    .frame(width: 18, height: 18)
                    .overlay {
                        Circle()
                            .stroke(Color.primary.opacity(settings.accent == preset ? 0.9 : 0), lineWidth: 2)
                            .padding(-2)
                    }
                    .contentShape(Circle())
                    .onTapGesture { settings.accent = preset }
            }
        }
    }

    // MARK: Notifications

    private var notificationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("settings.notifications").sectionTitle()

            VStack(spacing: 10) {
                HStack {
                    Text("settings.usageAlert")
                        .font(.system(size: 12.5, weight: .medium))
                    Spacer()
                    Picker("", selection: $settings.usageAlertThreshold) {
                        ForEach(UsageAlertThreshold.allCases) { threshold in
                            Text(threshold.title).tag(threshold)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 90)
                }

                Divider()

                Toggle(isOn: $settings.showUsageInMenuBar) {
                    Text("settings.showUsageInMenuBar")
                        .font(.system(size: 12.5, weight: .medium))
                }
                .toggleStyle(.switch)
            }
        }
        .padding(12)
        .background(appCardBackground)
    }

    // MARK: Providers

    private var providersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("settings.providers").sectionTitle()

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
