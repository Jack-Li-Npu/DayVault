import DayVaultCore
import SwiftUI

struct AchievementBadge: View {
    let definition: AchievementDefinition
    let unlocked: Bool
    let progress: Double
    var size: CGFloat = 76

    @AppStorage("badgeFrameAppearance") private var frameAppearanceRaw = BadgeFrameAppearance.classic.rawValue

    private var catalogIndex: Int {
        (AchievementCatalog.all.firstIndex(where: { $0.id == definition.id }) ?? 0) + 1
    }

    private var signalColor: Color {
        switch definition.category {
        case .beginnings: EditorialPalette.acid
        case .consistency: EditorialPalette.coral
        case .reflection: EditorialPalette.mint
        case .mastery: EditorialPalette.cobalt
        case .balance: EditorialPalette.sun
        case .discovery: Color(hex: "#E9A6FF")
        }
    }

    var body: some View {
        ZStack {
            if unlocked {
                unlockedBadge
            } else {
                lockedBadge
            }
            badgeFrame
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var unlockedBadge: some View {
        ZStack {
            CutCornerBadgeShape(cut: size * 0.18)
                .fill(signalColor)
            BadgeMotif(index: catalogIndex, color: Color(hex: "#171714"))
                .padding(size * 0.18)
            VStack {
                HStack(alignment: .top) {
                    Text(String(format: "%02d", catalogIndex))
                        .font(.system(size: size * 0.15, weight: .black, design: .monospaced))
                    Spacer()
                    Text(categoryCode)
                        .font(.system(size: size * 0.11, weight: .black, design: .monospaced))
                }
                Spacer()
            }
            .foregroundStyle(Color(hex: "#171714"))
            .padding(size * 0.10)
        }
        .overlay {
            CutCornerBadgeShape(cut: size * 0.18)
                .stroke(Color(hex: "#171714"), lineWidth: max(2, size * 0.035))
        }
        .background(alignment: .bottomTrailing) {
            CutCornerBadgeShape(cut: size * 0.18)
                .fill(Color(hex: "#171714"))
                .offset(x: size * 0.065, y: size * 0.065)
        }
    }

    private var lockedBadge: some View {
        ZStack {
            CutCornerBadgeShape(cut: size * 0.18)
                .fill(Color.white.opacity(0.055))
            BadgeHatch()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .clipShape(CutCornerBadgeShape(cut: size * 0.18))
            Text(definition.isHidden ? "??" : String(format: "%02d", catalogIndex))
                .font(.system(size: size * 0.26, weight: .black, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.34))
            if !definition.isHidden {
                VStack {
                    Spacer()
                    GeometryReader { proxy in
                        Rectangle()
                            .fill(EditorialPalette.acid)
                            .frame(width: proxy.size.width * min(max(progress, 0), 1), height: max(3, size * 0.045))
                    }
                    .frame(height: max(3, size * 0.045))
                }
                .padding(size * 0.10)
            }
        }
        .overlay {
            CutCornerBadgeShape(cut: size * 0.18)
                .stroke(Color.white.opacity(0.24), lineWidth: max(1, size * 0.022))
        }
    }

    @ViewBuilder
    private var badgeFrame: some View {
        switch BadgeFrameAppearance(rawValue: frameAppearanceRaw) ?? .classic {
        case .classic:
            EmptyView()
        case .minimal:
            CutCornerBadgeShape(cut: size * 0.18)
                .stroke(Color.white.opacity(0.54), lineWidth: 1)
                .padding(size * 0.06)
        case .prism:
            ZStack {
                CutCornerBadgeShape(cut: size * 0.18)
                    .stroke(EditorialPalette.coral, lineWidth: max(2, size * 0.03))
                CutCornerBadgeShape(cut: size * 0.14)
                    .stroke(EditorialPalette.acid, lineWidth: max(1, size * 0.018))
                    .padding(size * 0.055)
            }
        }
    }

    private var categoryCode: String {
        switch definition.category {
        case .beginnings: "BEG"
        case .consistency: "RUN"
        case .reflection: "REF"
        case .mastery: "MAS"
        case .balance: "BAL"
        case .discovery: "DIS"
        }
    }
}

private struct CutCornerBadgeShape: Shape {
    let cut: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
        path.closeSubpath()
        return path
    }
}

private struct BadgeHatch: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = max(7, rect.width / 8)
        var position = -rect.height
        while position < rect.width {
            path.move(to: CGPoint(x: position, y: rect.maxY))
            path.addLine(to: CGPoint(x: position + rect.height, y: rect.minY))
            position += step
        }
        return path
    }
}

private struct BadgeMotif: View {
    let index: Int
    let color: Color

    var body: some View {
        Canvas { context, size in
            let stroke = StrokeStyle(lineWidth: max(2, size.width * 0.065), lineCap: .square, lineJoin: .miter)
            var path = Path()
            switch (index - 1) % 8 {
            case 0:
                path.move(to: CGPoint(x: 0, y: size.height * 0.75))
                path.addLine(to: CGPoint(x: size.width * 0.28, y: size.height * 0.42))
                path.addLine(to: CGPoint(x: size.width * 0.50, y: size.height * 0.64))
                path.addLine(to: CGPoint(x: size.width, y: size.height * 0.12))
            case 1:
                path.addRect(CGRect(x: 0, y: size.height * 0.52, width: size.width * 0.28, height: size.height * 0.48))
                path.addRect(CGRect(x: size.width * 0.36, y: size.height * 0.27, width: size.width * 0.28, height: size.height * 0.73))
                path.addRect(CGRect(x: size.width * 0.72, y: 0, width: size.width * 0.28, height: size.height))
            case 2:
                path.addEllipse(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                path.move(to: CGPoint(x: size.width * 0.5, y: 0))
                path.addLine(to: CGPoint(x: size.width * 0.5, y: size.height))
                path.move(to: CGPoint(x: 0, y: size.height * 0.5))
                path.addLine(to: CGPoint(x: size.width, y: size.height * 0.5))
            case 3:
                path.move(to: CGPoint(x: 0, y: size.height))
                path.addLine(to: CGPoint(x: size.width * 0.5, y: 0))
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
                path.move(to: CGPoint(x: size.width * 0.2, y: size.height * 0.6))
                path.addLine(to: CGPoint(x: size.width * 0.8, y: size.height * 0.6))
            case 4:
                path.addRect(CGRect(x: 0, y: 0, width: size.width * 0.44, height: size.height * 0.44))
                path.addRect(CGRect(x: size.width * 0.56, y: 0, width: size.width * 0.44, height: size.height * 0.44))
                path.addRect(CGRect(x: 0, y: size.height * 0.56, width: size.width * 0.44, height: size.height * 0.44))
                path.addRect(CGRect(x: size.width * 0.56, y: size.height * 0.56, width: size.width * 0.44, height: size.height * 0.44))
            case 5:
                path.move(to: CGPoint(x: 0, y: size.height * 0.22))
                path.addLine(to: CGPoint(x: size.width, y: size.height * 0.22))
                path.move(to: CGPoint(x: 0, y: size.height * 0.50))
                path.addLine(to: CGPoint(x: size.width * 0.72, y: size.height * 0.50))
                path.move(to: CGPoint(x: 0, y: size.height * 0.78))
                path.addLine(to: CGPoint(x: size.width * 0.46, y: size.height * 0.78))
            case 6:
                path.move(to: CGPoint(x: size.width * 0.5, y: 0))
                path.addLine(to: CGPoint(x: size.width, y: size.height * 0.5))
                path.addLine(to: CGPoint(x: size.width * 0.5, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height * 0.5))
                path.closeSubpath()
                path.addEllipse(in: CGRect(
                    x: size.width * 0.34,
                    y: size.height * 0.34,
                    width: size.width * 0.32,
                    height: size.height * 0.32
                ))
            default:
                path.move(to: CGPoint(x: 0, y: size.height * 0.50))
                path.addCurve(
                    to: CGPoint(x: size.width, y: size.height * 0.50),
                    control1: CGPoint(x: size.width * 0.25, y: 0),
                    control2: CGPoint(x: size.width * 0.75, y: size.height)
                )
                path.move(to: CGPoint(x: size.width * 0.20, y: 0))
                path.addLine(to: CGPoint(x: size.width * 0.20, y: size.height))
                path.move(to: CGPoint(x: size.width * 0.80, y: 0))
                path.addLine(to: CGPoint(x: size.width * 0.80, y: size.height))
            }
            context.stroke(path, with: .color(color), style: stroke)

            // A five-bit edge code makes every badge in the 24-piece set unique,
            // even when two achievements share the same broad motif family.
            let marker = max(2, size.width * 0.075)
            let gap = marker * 1.45
            for bit in 0..<5 where index & (1 << bit) != 0 {
                let rect = CGRect(
                    x: CGFloat(bit) * gap,
                    y: size.height - marker,
                    width: marker,
                    height: marker
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
    }
}
