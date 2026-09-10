import DayVaultCore
import SwiftUI
import UIKit

enum EditorialPalette {
    static let paper = adaptive(light: "#F4F0E7", dark: "#151512")
    static let sheet = adaptive(light: "#FFFDF7", dark: "#1E1E19")
    static let ink = adaptive(light: "#171714", dark: "#F5F1E8")
    static let muted = adaptive(light: "#6E6B62", dark: "#AAA69C")
    static let rule = adaptive(light: "#171714", dark: "#F5F1E8").opacity(0.18)
    static let cobalt = Color(hex: "#4F46E5")
    static let coral = Color(hex: "#FF6B4A")
    // Saturated display colors stay bright; text variants meet contrast on paper.
    static let coralText = adaptive(light: "#A93620", dark: "#FF9A84")
    static let mintText = adaptive(light: "#176B4E", dark: "#82E7BE")
    static let acid = Color(hex: "#DDFB58")
    static let mint = Color(hex: "#67D7AC")
    static let sun = Color(hex: "#FFC857")
    static let vault = Color(hex: "#11110F")
    static let vaultSheet = Color(hex: "#1D1D18")
    static let vaultRule = Color.white.opacity(0.16)

    static func category(_ category: ScheduleCategory?) -> Color {
        switch category?.balanceGroup ?? .other {
        case .focus: cobalt
        case .care: coral
        case .rest: mint
        case .other: sun
        }
    }

    private static func adaptive(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
}

struct EditorialBackdrop: View {
    var body: some View {
        EditorialPalette.paper
            .ignoresSafeArea()
            .overlay(alignment: .topTrailing) {
                EditorialCornerMark()
                    .fill(EditorialPalette.ink.opacity(0.08))
                    .frame(width: 92, height: 92)
                    .offset(x: 26, y: -18)
                    .accessibilityHidden(true)
            }
    }
}

private struct EditorialCornerMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = rect.width / 6
        for index in 0..<6 {
            let inset = CGFloat(index) * step
            path.addRect(CGRect(x: rect.maxX - step - inset, y: rect.minY + inset, width: step, height: step))
        }
        return path
    }
}

struct DayVaultMark: View {
    var size: CGFloat = 42
    var foreground: Color = EditorialPalette.ink
    var cutout: Color = EditorialPalette.acid

    var body: some View {
        ZStack {
            DayVaultDShape()
                .fill(foreground)
            DayVaultVShape()
                .fill(cutout)
                .padding(size * 0.21)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct DayVaultDShape: Shape {
    func path(in rect: CGRect) -> Path {
        let x = rect.width
        let y = rect.height
        var path = Path()
        path.move(to: CGPoint(x: x * 0.14, y: y * 0.08))
        path.addLine(to: CGPoint(x: x * 0.49, y: y * 0.08))
        path.addCurve(
            to: CGPoint(x: x * 0.90, y: y * 0.50),
            control1: CGPoint(x: x * 0.76, y: y * 0.08),
            control2: CGPoint(x: x * 0.90, y: y * 0.24)
        )
        path.addCurve(
            to: CGPoint(x: x * 0.49, y: y * 0.92),
            control1: CGPoint(x: x * 0.90, y: y * 0.76),
            control2: CGPoint(x: x * 0.76, y: y * 0.92)
        )
        path.addLine(to: CGPoint(x: x * 0.14, y: y * 0.92))
        path.closeSubpath()
        return path
    }
}

private struct DayVaultVShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.width * 0.33, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.width * 0.67, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.width * 0.69, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.width * 0.31, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct EditorialMenuGlyph: View {
    var color: Color = EditorialPalette.ink

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Rectangle().frame(width: 20, height: 2)
            Rectangle().frame(width: 14, height: 2)
            Rectangle().frame(width: 20, height: 2)
        }
        .foregroundStyle(color)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
}

struct EditorialArrowGlyph: View {
    var color: Color = EditorialPalette.ink

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: size.width * 0.18, y: size.height * 0.5))
            path.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.5))
            path.move(to: CGPoint(x: size.width * 0.56, y: size.height * 0.28))
            path.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.5))
            path.addLine(to: CGPoint(x: size.width * 0.56, y: size.height * 0.72))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.4, lineCap: .square, lineJoin: .miter))
        }
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
    }
}

struct EditorialCheckmark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.18, y: rect.height * 0.52))
        path.addLine(to: CGPoint(x: rect.width * 0.42, y: rect.height * 0.76))
        path.addLine(to: CGPoint(x: rect.width * 0.84, y: rect.height * 0.24))
        return path
    }
}

struct EditorialCardModifier: ViewModifier {
    var fill: Color = EditorialPalette.sheet
    var border: Color = EditorialPalette.ink
    var radius: CGFloat = 14
    var shadow: Bool = true

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(border.opacity(0.9), lineWidth: 1)
            }
            .background(alignment: .bottomTrailing) {
                if shadow {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(border)
                        .offset(x: 4, y: 4)
                }
            }
    }
}

struct EditorialPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var fill: Color = EditorialPalette.ink
    var foreground: Color = EditorialPalette.paper

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(foreground)
            .frame(minHeight: 48)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .background(fill)
            .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
            .offset(x: configuration.isPressed ? 3 : 0, y: configuration.isPressed ? 3 : 0)
            .background(EditorialPalette.ink.offset(x: 3, y: 3))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func editorialCard(
        fill: Color = EditorialPalette.sheet,
        border: Color = EditorialPalette.ink,
        radius: CGFloat = 14,
        shadow: Bool = true
    ) -> some View {
        modifier(EditorialCardModifier(fill: fill, border: border, radius: radius, shadow: shadow))
    }
}
