import SwiftUI
import UIKit

enum PlannerAppearance: String, CaseIterable, Identifiable {
    case dayVault, dawn, forest, sunset, monochrome

    var id: String { rawValue }
    var titleKey: LocalizedStringKey { LocalizedStringKey("appearance.planner.\(rawValue)") }
    var lightHex: String {
        switch self {
        case .dayVault: "#F4F0E7"
        case .dawn: "#FFF8F1"
        case .forest: "#F2F8F4"
        case .sunset: "#FFF4F5"
        case .monochrome: "#F5F5F5"
        }
    }
    var darkHex: String {
        switch self {
        case .dayVault: "#151512"
        case .dawn: "#211510"
        case .forest: "#0C1B16"
        case .sunset: "#211016"
        case .monochrome: "#111111"
        }
    }
}

enum VaultAppearance: String, CaseIterable, Identifiable {
    case obsidian, nebula, emerald
    var id: String { rawValue }
    var titleKey: LocalizedStringKey { LocalizedStringKey("appearance.vault.\(rawValue)") }
}

enum BadgeFrameAppearance: String, CaseIterable, Identifiable {
    case classic, minimal, prism
    var id: String { rawValue }
    var titleKey: LocalizedStringKey { LocalizedStringKey("appearance.badge.\(rawValue)") }
}

enum WidgetAppearance: String, CaseIterable, Identifiable {
    case midnight, light, violet
    var id: String { rawValue }
    var titleKey: LocalizedStringKey { LocalizedStringKey("appearance.widget.\(rawValue)") }
}

enum AppIconAppearance: String, CaseIterable, Identifiable {
    case primary, emerald, graphite
    var id: String { rawValue }
    var titleKey: LocalizedStringKey { LocalizedStringKey("appearance.icon.\(rawValue)") }
    var assetName: String? {
        switch self { case .primary: nil; case .emerald: "AppIconEmerald"; case .graphite: "AppIconGraphite" }
    }
}

enum DayVaultPalette {
    static let plannerLight = Color(hex: "#F4F0E7")
    static let plannerDark = Color(hex: "#151512")
    static let cyan = Color(hex: "#4F46E5")
    static let violet = Color(hex: "#FF6B4A")
    static let success = Color(hex: "#67D7AC")
    static let warning = Color(hex: "#FFC857")
    static let vaultBackground = Color(hex: "#11110F")
    static let vaultSurface = Color(hex: "#1D1D18")
    static let vaultCyan = Color(hex: "#DDFB58")
    static let vaultViolet = Color(hex: "#FF6B4A")
    static let vaultGold = Color(hex: "#FFC857")
}

extension Color {
    init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var integer: UInt64 = 0
        Scanner(string: value).scanHexInt64(&integer)
        let red, green, blue: UInt64
        switch value.count {
        case 6:
            red = integer >> 16
            green = integer >> 8 & 0xFF
            blue = integer & 0xFF
        default:
            red = 73
            green = 207
            blue = 245
        }
        self.init(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255, opacity: 1)
    }

    var hexRGB: String {
        let components = UIColor(self).cgColor.components ?? [0, 0, 0]
        let red = components[0]
        let green = components.count > 2 ? components[1] : components[0]
        let blue = components.count > 2 ? components[2] : components[0]
        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}

struct PlannerBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("plannerAppearance") private var appearanceRaw = PlannerAppearance.dayVault.rawValue

    var body: some View {
        let appearance = PlannerAppearance(rawValue: appearanceRaw) ?? .dayVault
        return Color(hex: colorScheme == .dark ? appearance.darkHex : appearance.lightHex)
            .ignoresSafeArea()
    }
}

struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
    }
}

extension View {
    func glassCard() -> some View { modifier(GlassCardModifier()) }
}
