import SwiftUI

/// A separate paper companion, not the user's achievement avatar.
struct OrigamiCompanion: View {
    var days = 0
    var isCelebrating = false
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.avatarReducedMotionPreview) private var previewReduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var moving: Bool { animated && !reduceMotion && !previewReduceMotion && scenePhase == .active }
    private var stage: Int {
        if days >= 30 { return 2 }
        if days >= 7 { return 1 }
        return 0
    }
    private var stageDescription: String {
        switch stage {
        case 0: "初见"
        case 1: "渐入默契"
        default: "配合熟练"
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !moving)) { timeline in
            Canvas { context, size in
                let scale = min(size.width / 160, size.height / 160)
                context.translateBy(x: (size.width - 160 * scale) / 2, y: (size.height - 160 * scale) / 2)
                context.scaleBy(x: scale, y: scale)
                let t = moving ? timeline.date.timeIntervalSinceReferenceDate : 0
                let breath = moving ? sin(t * (isCelebrating ? 7 : 2.3)) : 0
                context.fill(Path(ellipseIn: CGRect(x: 45, y: 133, width: 76, height: 8)), with: .color(.black.opacity(0.1)))
                context.translateBy(x: 80, y: 96 - breath * (isCelebrating ? 4 : 1.5))
                context.rotate(by: .degrees(breath * (isCelebrating ? 5 : 1.2)))
                context.translateBy(x: -80, y: -96)
                drawFigure(in: context, time: t)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("折纸伙伴")
        .accessibilityValue(stageDescription)
    }

    private func drawFigure(in context: GraphicsContext, time: TimeInterval) {
        let ink = Color(hex: "#24291F")
        let paper = Color(hex: "#FFF5CF")
        let fold = Color(hex: "#E6DBAE")
        let edge = Color(hex: "#CCDF92")

        func polygon(_ points: [(CGFloat, CGFloat)], color: Color, width: CGFloat = 2.4) {
            var path = Path()
            if let first = points.first { path.move(to: CGPoint(x: first.0, y: first.1)) }
            for point in points.dropFirst() { path.addLine(to: CGPoint(x: point.0, y: point.1)) }
            path.closeSubpath()
            context.fill(path, with: .color(color))
            context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: width, lineJoin: .round))
        }
        if stage >= 1 {
            let tip: CGFloat = stage == 2 ? 16 : 28
            polygon([(62, 91), (tip, 51), (35, 106), (65, 115)], color: stage == 2 ? edge : paper)
            polygon([(99, 87), (160 - tip, 44), (129, 107), (101, 113)], color: stage == 2 ? edge : paper)
            polygon([(99, 87), (160 - tip, 44), (117, 86)], color: paper, width: 1.5)
        }
        polygon([(57, 116), (51, 133), (75, 130), (81, 114)], color: ink, width: 1.3)
        polygon([(91, 116), (90, 132), (112, 134), (108, 113)], color: ink, width: 1.3)
        polygon([(45, 73), (74, 36), (116, 65), (110, 118), (79, 128), (47, 111)], color: paper)
        polygon([(74, 36), (83, 79), (116, 65)], color: fold, width: 1.5)
        polygon([(47, 111), (83, 79), (79, 128)], color: fold, width: 1.5)
        polygon([(83, 79), (110, 118), (79, 128)], color: stage == 2 ? edge : paper, width: 1.5)
        polygon([(45, 73), (83, 79), (62, 88)], color: Color(hex: "#FAEBA9"), width: 1.2)

        let blink = moving && time.truncatingRemainder(dividingBy: 4.8) > 4.65
        for x: CGFloat in [61, 95] {
            let height: CGFloat = blink ? 1.5 : 6
            context.fill(Path(roundedRect: CGRect(x: x, y: 89, width: 4.5, height: height), cornerRadius: 2), with: .color(ink))
        }
        if stage >= 1 {
            polygon([(99, 59), (105, 62), (102, 69), (96, 65)], color: Color(hex: "#F17B59"), width: 1.2)
        }
        if stage == 2 {
            polygon([(75, 36), (69, 19), (92, 29), (86, 47)], color: paper, width: 1.6)
        }
    }
}
