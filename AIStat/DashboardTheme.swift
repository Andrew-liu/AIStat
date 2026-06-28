import SwiftUI

extension Color {
    static func providerAccent(_ name: String) -> Color {
        switch name {
        case "purple": return Color(red: 0.62, green: 0.46, blue: 0.95)
        case "blue": return Color(red: 0.24, green: 0.55, blue: 0.95)
        case "green": return Color(red: 0.16, green: 0.72, blue: 0.36)
        case "orange": return Color(red: 0.95, green: 0.52, blue: 0.18)
        case "red": return Color(red: 0.92, green: 0.24, blue: 0.24)
        case "pink": return Color(red: 0.95, green: 0.35, blue: 0.60)
        default: return Color.primary.opacity(0.82)
        }
    }
}

extension Text {
    func sectionTitle() -> some View {
        self.font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    func valueText() -> some View {
        self.font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
    }
}

var appCardBackground: some View {
    RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(.background.opacity(0.72))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.separator.opacity(0.42), lineWidth: 0.5)
        }
}

func percent(_ value: Double?) -> String {
    guard let value else { return "--" }
    return "\(Int(max(0, min(100, value)).rounded()))%"
}

func decimal(_ value: Double?) -> String {
    guard let value else { return "--" }
    return String(format: "%.2f", value)
}

func gb(_ value: Double?) -> String {
    guard let value else { return "--" }
    return String(format: "%.2f GB", value)
}

func batterySymbol(for value: Double?) -> String {
    guard let value else { return "battery.0" }
    switch value {
    case 75...: return "battery.100"
    case 50..<75: return "battery.75"
    case 25..<50: return "battery.50"
    case 10..<25: return "battery.25"
    default: return "battery.0"
    }
}
