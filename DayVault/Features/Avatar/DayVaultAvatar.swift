import DayVaultCore
import SwiftUI

private struct AvatarReducedMotionPreviewKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Debug previews use the same reduced-motion branch without changing system settings.
    var avatarReducedMotionPreview: Bool {
        get { self[AvatarReducedMotionPreviewKey.self] }
        set { self[AvatarReducedMotionPreviewKey.self] = newValue }
    }
}

enum AvatarPose: String, CaseIterable {
    case idle, wave, proud, celebrate
}

/// An original, layered character. All artwork is drawn locally; clothing is earned history.
struct DayVaultAvatar: View {
    var outfit: AvatarOutfit = .init()
    var pose: AvatarPose = .idle
    var animated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.avatarReducedMotionPreview) private var previewReduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var hasMotion: Bool { animated && !reduceMotion && !previewReduceMotion && scenePhase == .active }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !hasMotion)) { timeline in
            AvatarCanvas(
                outfit: outfit,
                wave: pose == .wave ? 1 : 0,
                proud: pose == .proud ? 1 : 0,
                celebrate: pose == .celebrate ? 1 : 0,
                time: hasMotion ? timeline.date.timeIntervalSinceReferenceDate : 0,
                moving: hasMotion
            )
            .animation(hasMotion ? .spring(response: 0.5, dampingFraction: 0.8) : nil, value: pose)
        }
        .accessibilityHidden(true)
    }
}

private struct AvatarCanvas: View, Animatable {
    var outfit: AvatarOutfit
    nonisolated var wave: Double
    nonisolated var proud: Double
    nonisolated var celebrate: Double
    let time: TimeInterval
    let moving: Bool

    nonisolated var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(wave, AnimatablePair(proud, celebrate)) }
        set {
            wave = newValue.first
            proud = newValue.second.first
            celebrate = newValue.second.second
        }
    }

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 240, size.height / 300)
            context.translateBy(x: (size.width - 240 * scale) / 2, y: (size.height - 300 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            AvatarIllustration(outfit: outfit, wave: wave, proud: proud, celebrate: celebrate, time: time, moving: moving)
                .draw(in: context)
        }
    }
}

private struct AvatarIllustration {
    let outfit: AvatarOutfit
    let wave: Double
    let proud: Double
    let celebrate: Double
    let time: TimeInterval
    let moving: Bool

    private let ink = Color(hex: "#20231F")
    private let skin = Color(hex: "#DCA783")
    private let skinShadow = Color(hex: "#BD8163")
    private let cream = Color(hex: "#EFE5CD")
    private let navy = Color(hex: "#363C50")
    private let cobalt = Color(hex: "#514BEC")
    private let acid = Color(hex: "#DDFB58")
    private let coral = Color(hex: "#F17657")

    private var varsity: Bool { outfit.outerwear == "rhythm_varsity" }
    private var jacket: Bool { outfit.outerwear == "ten_jacket" }
    private var outerwear: Bool { varsity || jacket }
    private var shirt: Color {
        if varsity { return ink }
        if jacket { return cobalt }
        return cream
    }
    private var sleeve: Color { varsity ? acid : shirt }
    private var breathing: CGFloat { moving ? CGFloat(sin(time * 2.1)) : 0 }

    func draw(in context: GraphicsContext) {
        var ground = context
        ground.opacity = 0.13
        ground.fill(Path(ellipseIn: CGRect(x: 69, y: 281, width: 115, height: 12)), with: .color(ink))

        var figure = context
        figure.translateBy(x: 0, y: -breathing * 1.1)
        legs(in: figure)
        arm(left: true, in: figure)
        arm(left: false, in: figure)
        torso(in: figure)
        if outfit.accessory == "month_satchel" { satchel(in: figure) }
        head(in: figure)
    }

    private func legs(in context: GraphicsContext) {
        fill(path { p in
            p.move(to: CGPoint(x: 93, y: 190))
            p.addLine(to: CGPoint(x: 84, y: 250))
            p.addQuadCurve(to: CGPoint(x: 87, y: 269), control: CGPoint(x: 81, y: 263))
            p.addLine(to: CGPoint(x: 114, y: 271))
            p.addLine(to: CGPoint(x: 123, y: 218))
            p.addLine(to: CGPoint(x: 128, y: 270))
            p.addLine(to: CGPoint(x: 158, y: 269))
            p.addQuadCurve(to: CGPoint(x: 160, y: 247), control: CGPoint(x: 162, y: 257))
            p.addLine(to: CGPoint(x: 152, y: 191))
            p.closeSubpath()
        }, color: navy, in: context)

        fill(path { p in
            p.move(to: CGPoint(x: 112, y: 205))
            p.addLine(to: CGPoint(x: 103, y: 264))
            p.addLine(to: CGPoint(x: 113, y: 266))
            p.addLine(to: CGPoint(x: 123, y: 217))
            p.addLine(to: CGPoint(x: 129, y: 266))
            p.addLine(to: CGPoint(x: 137, y: 265))
            p.addLine(to: CGPoint(x: 128, y: 205))
            p.closeSubpath()
        }, color: ink.opacity(0.3), outline: false, in: context)

        line([(93, 223), (106, 225), (105, 241), (91, 239)], color: Color.white.opacity(0.18), width: 1.7, in: context)
        line([(140, 216), (151, 215), (153, 232), (142, 234), (140, 216)], color: Color.white.opacity(0.18), width: 1.7, in: context)
        line([(89, 259), (112, 261)], color: ink, width: 2, in: context)
        line([(130, 260), (156, 259)], color: ink, width: 2, in: context)
        shoe(left: true, in: context)
        shoe(left: false, in: context)
    }

    private func shoe(left: Bool, in context: GraphicsContext) {
        var shoeContext = context
        shoeContext.translateBy(x: left ? 75 : 128, y: 264)
        if !left {
            shoeContext.translateBy(x: 49, y: 0)
            shoeContext.scaleBy(x: -1, y: 1)
        }
        fill(path { p in
            p.move(to: CGPoint(x: 16, y: 1))
            p.addLine(to: CGPoint(x: 38, y: 1))
            p.addLine(to: CGPoint(x: 44, y: 12))
            p.addQuadCurve(to: CGPoint(x: 43, y: 20), control: CGPoint(x: 47, y: 17))
            p.addLine(to: CGPoint(x: 2, y: 20))
            p.addQuadCurve(to: CGPoint(x: 1, y: 12), control: CGPoint(x: -1, y: 15))
            p.addQuadCurve(to: CGPoint(x: 16, y: 1), control: CGPoint(x: 3, y: 6))
            p.closeSubpath()
        }, color: cream, in: shoeContext)
        fill(path { p in
            p.move(to: CGPoint(x: 15, y: 2))
            p.addLine(to: CGPoint(x: 24, y: 2))
            p.addLine(to: CGPoint(x: 17, y: 12))
            p.addLine(to: CGPoint(x: 7, y: 12))
            p.closeSubpath()
        }, color: jacket ? acid : coral, outline: false, in: shoeContext)
        line([(2, 15), (42, 15)], color: ink, width: 1.6, in: shoeContext)
        line([(23, 5), (31, 7)], color: ink, width: 1.5, in: shoeContext)
        line([(20, 9), (28, 11)], color: ink, width: 1.5, in: shoeContext)
        line([(8, 19), (8, 21), (17, 21), (17, 19)], color: ink, width: 1.5, in: shoeContext)
    }

    private func arm(left: Bool, in context: GraphicsContext) {
        let points = armPoints(left: left)
        let shoulder = points.0
        let elbow = points.1
        let hand = points.2
        let forearm = path { p in
            p.move(to: elbow)
            p.addLine(to: hand)
        }
        stroke(forearm, color: ink, width: 20, in: context)
        stroke(forearm, color: outerwear ? sleeve : skin, width: 15, in: context)
        let upper = path { p in
            p.move(to: shoulder)
            p.addLine(to: elbow)
        }
        stroke(upper, color: ink, width: 28, in: context)
        stroke(upper, color: sleeve, width: 23, in: context)

        if outerwear {
            let cuff = CGPoint(x: hand.x * 0.81 + elbow.x * 0.19, y: hand.y * 0.81 + elbow.y * 0.19)
            fill(Path(ellipseIn: CGRect(x: cuff.x - 9, y: cuff.y - 7, width: 18, height: 14)), color: varsity ? cream : ink, in: context, width: 1.7)
        }
        fill(Path(ellipseIn: CGRect(x: hand.x - 8, y: hand.y - 7, width: 17, height: 20)), color: skin, in: context, width: 2.1)
        line([(hand.x + 2, hand.y + 4), (hand.x + 2, hand.y + 8)], color: skinShadow, width: 1.5, in: context)

        if !left && outfit.accessory == "starter_band" {
            let wrist = CGPoint(x: hand.x * 0.77 + elbow.x * 0.23, y: hand.y * 0.77 + elbow.y * 0.23)
            fill(Path(roundedRect: CGRect(x: wrist.x - 10, y: wrist.y - 6, width: 20, height: 11), cornerRadius: 3), color: acid, in: context, width: 1.8)
            line([(wrist.x - 5, wrist.y - 3), (wrist.x - 5, wrist.y + 1)], color: ink, width: 1.5, in: context)
        }
        if !left && varsity {
            let center = CGPoint(x: shoulder.x * 0.42 + elbow.x * 0.58, y: shoulder.y * 0.42 + elbow.y * 0.58)
            fill(Path(roundedRect: CGRect(x: center.x - 8, y: center.y - 8, width: 17, height: 17), cornerRadius: 3), color: ink, outline: false, in: context)
            text("VII", at: center, size: 8, color: acid, in: context)
        }
    }

    private func armPoints(left: Bool) -> (CGPoint, CGPoint, CGPoint) {
        let idlePoints = armPoints(left: left, pose: .idle)
        let wavePoints = armPoints(left: left, pose: .wave)
        let proudPoints = armPoints(left: left, pose: .proud)
        let celebratePoints = armPoints(left: left, pose: .celebrate)
        func blend(_ idle: CGPoint, _ waved: CGPoint, _ posed: CGPoint, _ raised: CGPoint) -> CGPoint {
            let waveX = (waved.x - idle.x) * CGFloat(wave)
            let waveY = (waved.y - idle.y) * CGFloat(wave)
            let proudX = (posed.x - idle.x) * CGFloat(proud)
            let proudY = (posed.y - idle.y) * CGFloat(proud)
            let raisedX = (raised.x - idle.x) * CGFloat(celebrate)
            let raisedY = (raised.y - idle.y) * CGFloat(celebrate)
            return CGPoint(x: idle.x + waveX + proudX + raisedX, y: idle.y + waveY + proudY + raisedY)
        }
        return (
            idlePoints.0,
            blend(idlePoints.1, wavePoints.1, proudPoints.1, celebratePoints.1),
            blend(idlePoints.2, wavePoints.2, proudPoints.2, celebratePoints.2)
        )
    }

    private func armPoints(left: Bool, pose: AvatarPose) -> (CGPoint, CGPoint, CGPoint) {
        let shoulder = CGPoint(x: left ? 93 : 152, y: 146)
        switch pose {
        case .idle:
            return (shoulder, CGPoint(x: left ? 78 : 167, y: 176), CGPoint(x: left ? 80 : 165, y: 204))
        case .proud:
            return (shoulder, CGPoint(x: left ? 70 : 178, y: 168), CGPoint(x: left ? 94 : 157, y: 187))
        case .wave:
            if left { return (shoulder, CGPoint(x: 77, y: 176), CGPoint(x: 80, y: 205)) }
            let wave: CGFloat = moving ? CGFloat(sin(time * 5)) * 4 : 0
            return (shoulder, CGPoint(x: 178, y: 135), CGPoint(x: 183 + wave, y: 107))
        case .celebrate:
            return (shoulder, CGPoint(x: left ? 66 : 178, y: 133), CGPoint(x: left ? 52 : 187, y: left ? 108 : 99))
        }
    }

    private func torso(in context: GraphicsContext) {
        fill(Path(roundedRect: CGRect(x: 109, y: 116, width: 29, height: 29), cornerRadius: 8), color: skinShadow, in: context)
        fill(path { p in
            p.move(to: CGPoint(x: 95, y: 134))
            p.addQuadCurve(to: CGPoint(x: 109, y: 131), control: CGPoint(x: 100, y: 130))
            p.addQuadCurve(to: CGPoint(x: 138, y: 131), control: CGPoint(x: 124, y: 143))
            p.addQuadCurve(to: CGPoint(x: 151, y: 137), control: CGPoint(x: 145, y: 132))
            p.addLine(to: CGPoint(x: 158, y: 163))
            p.addLine(to: CGPoint(x: 157, y: 202))
            p.addQuadCurve(to: CGPoint(x: 90, y: 205), control: CGPoint(x: 126, y: 216))
            p.addLine(to: CGPoint(x: 87, y: 164))
            p.closeSubpath()
        }, color: shirt, in: context)

        fill(path { p in
            p.move(to: CGPoint(x: 91, y: 165))
            p.addLine(to: CGPoint(x: 101, y: 190))
            p.addLine(to: CGPoint(x: 101, y: 207))
            p.addLine(to: CGPoint(x: 92, y: 205))
            p.closeSubpath()
        }, color: ink.opacity(0.1), outline: false, in: context)
        line([(94, 199), (117, 203), (150, 199)], color: outerwear ? cream.opacity(0.4) : ink.opacity(0.3), width: 1.3, in: context)

        if outerwear {
            line([(124, 144), (125, 201)], color: cream, width: jacket ? 2 : 1.3, in: context)
            line([(109, 132), (116, 145), (123, 139), (132, 145), (138, 132)], color: varsity ? acid : cream, width: 3, in: context)
            line([(99, 177), (108, 185)], color: cream.opacity(0.6), width: 1.7, in: context)
            line([(141, 184), (150, 176)], color: cream.opacity(0.6), width: 1.7, in: context)
            if varsity {
                for y in [155.0, 170.0, 185.0] {
                    context.fill(Path(ellipseIn: CGRect(x: 120, y: y, width: 3, height: 3)), with: .color(cream))
                }
            } else {
                fill(Path(roundedRect: CGRect(x: 121, y: 150, width: 7, height: 10), cornerRadius: 2), color: ink, outline: false, in: context)
            }
        } else {
            stroke(path { p in
                p.move(to: CGPoint(x: 109, y: 133))
                p.addQuadCurve(to: CGPoint(x: 138, y: 133), control: CGPoint(x: 124, y: 151))
            }, color: ink, width: 2.2, in: context)
        }

        // The small stitched D is custom lettering, not a borrowed brand mark.
        var patch = context
        patch.translateBy(x: 100, y: 154)
        fill(Path(roundedRect: CGRect(x: 0, y: 0, width: 14, height: 17), cornerRadius: 3), color: varsity ? acid : cream, outline: false, in: patch)
        stroke(path { p in
            p.move(to: CGPoint(x: 4, y: 4))
            p.addLine(to: CGPoint(x: 4, y: 13))
            p.addCurve(to: CGPoint(x: 4, y: 4), control1: CGPoint(x: 13, y: 14), control2: CGPoint(x: 13, y: 3))
        }, color: ink, width: 2, in: patch)
    }

    private func satchel(in context: GraphicsContext) {
        line([(101, 137), (148, 190)], color: ink, width: 9, in: context)
        line([(101, 137), (148, 190)], color: coral, width: 5, in: context)
        fill(Path(roundedRect: CGRect(x: 136, y: 180, width: 37, height: 35), cornerRadius: 8), color: coral, in: context)
        fill(Path(roundedRect: CGRect(x: 136, y: 180, width: 37, height: 12), cornerRadius: 5), color: Color(hex: "#DF6244"), in: context, width: 1.7)
        line([(141, 190), (168, 190)], color: ink, width: 1.2, in: context)
        fill(Path(roundedRect: CGRect(x: 146, y: 194, width: 19, height: 15), cornerRadius: 2), color: cream, in: context, width: 1.2)
        text("20", at: CGPoint(x: 155.5, y: 201), size: 9, color: ink, in: context)
    }

    private func head(in context: GraphicsContext) {
        var headContext = context
        let tilt = -4 * proud
        headContext.translateBy(x: 124, y: 118)
        headContext.rotate(by: .degrees(tilt + Double(breathing) * 0.45))
        headContext.translateBy(x: -124, y: -118)

        if outfit.head == "comeback_bandana" { bandanaTails(in: headContext) }
        fill(Path(ellipseIn: CGRect(x: 81, y: 90, width: 22, height: 26)), color: skin, in: headContext)
        fill(Path(ellipseIn: CGRect(x: 152, y: 88, width: 20, height: 26)), color: skin, in: headContext)
        line([(88, 99), (92, 103), (88, 106)], color: skinShadow, width: 2, in: headContext)
        fill(path { p in
            p.move(to: CGPoint(x: 93, y: 65))
            p.addCurve(to: CGPoint(x: 158, y: 67), control1: CGPoint(x: 107, y: 45), control2: CGPoint(x: 150, y: 48))
            p.addCurve(to: CGPoint(x: 155, y: 116), control1: CGPoint(x: 165, y: 80), control2: CGPoint(x: 163, y: 103))
            p.addCurve(to: CGPoint(x: 112, y: 133), control1: CGPoint(x: 151, y: 132), control2: CGPoint(x: 128, y: 140))
            p.addCurve(to: CGPoint(x: 94, y: 110), control1: CGPoint(x: 99, y: 129), control2: CGPoint(x: 96, y: 122))
            p.addQuadCurve(to: CGPoint(x: 93, y: 65), control: CGPoint(x: 86, y: 90))
            p.closeSubpath()
        }, color: skin, in: headContext)
        fill(path { p in
            p.move(to: CGPoint(x: 98, y: 81))
            p.addCurve(to: CGPoint(x: 116, y: 131), control1: CGPoint(x: 91, y: 108), control2: CGPoint(x: 101, y: 121))
            p.addCurve(to: CGPoint(x: 96, y: 111), control1: CGPoint(x: 103, y: 126), control2: CGPoint(x: 97, y: 120))
            p.closeSubpath()
        }, color: skinShadow.opacity(0.6), outline: false, in: headContext)
        hair(in: headContext)
        face(in: headContext)
        if outfit.head == "rhythm_cap" { cap(in: headContext) }
        if outfit.head == "comeback_bandana" { bandana(in: headContext) }
    }

    private func hair(in context: GraphicsContext) {
        fill(path { p in
            p.move(to: CGPoint(x: 92, y: 95))
            p.addLine(to: CGPoint(x: 86, y: 77))
            p.addQuadCurve(to: CGPoint(x: 91, y: 54), control: CGPoint(x: 79, y: 60))
            p.addLine(to: CGPoint(x: 87, y: 48))
            p.addLine(to: CGPoint(x: 106, y: 47))
            p.addLine(to: CGPoint(x: 111, y: 39))
            p.addLine(to: CGPoint(x: 122, y: 44))
            p.addCurve(to: CGPoint(x: 161, y: 55), control1: CGPoint(x: 150, y: 39), control2: CGPoint(x: 160, y: 42))
            p.addQuadCurve(to: CGPoint(x: 158, y: 86), control: CGPoint(x: 173, y: 65))
            p.addLine(to: CGPoint(x: 151, y: 73))
            p.addQuadCurve(to: CGPoint(x: 116, y: 76), control: CGPoint(x: 128, y: 84))
            p.addLine(to: CGPoint(x: 123, y: 65))
            p.addQuadCurve(to: CGPoint(x: 100, y: 81), control: CGPoint(x: 108, y: 77))
            p.addLine(to: CGPoint(x: 98, y: 98))
            p.closeSubpath()
        }, color: ink, in: context, width: 2)
        stroke(path { p in
            p.move(to: CGPoint(x: 103, y: 60))
            p.addQuadCurve(to: CGPoint(x: 145, y: 53), control: CGPoint(x: 121, y: 49))
        }, color: Color(hex: "#4C4D43"), width: 3, in: context)
    }

    private func face(in context: GraphicsContext) {
        let blink = moving && time.truncatingRemainder(dividingBy: 4.7) > 4.54
        let delighted = celebrate > 0.5
        line([(107, 85), (116, 83)], color: ink, width: 2.8, in: context)
        line([(139, 82), (148, 84)], color: ink, width: 2.8, in: context)
        if blink || delighted {
            for x: CGFloat in [112, 144] {
                stroke(path { p in
                    p.move(to: CGPoint(x: x - 4, y: 96))
                    p.addQuadCurve(to: CGPoint(x: x + 4, y: 96), control: CGPoint(x: x, y: 90))
                }, color: ink, width: 3, in: context)
            }
        } else {
            for x: CGFloat in [111, 142] {
                fill(Path(roundedRect: CGRect(x: x - 2, y: 91, width: 6, height: 10), cornerRadius: 3), color: ink, outline: false, in: context)
            }
        }
        stroke(path { p in
            p.move(to: CGPoint(x: 128, y: 96))
            p.addLine(to: CGPoint(x: 126, y: 107))
            p.addQuadCurve(to: CGPoint(x: 132, y: 107), control: CGPoint(x: 130, y: 110))
        }, color: skinShadow, width: 2, in: context)
        if delighted || wave > 0.5 {
            fill(path { p in
                p.move(to: CGPoint(x: 118, y: 116))
                p.addQuadCurve(to: CGPoint(x: 139, y: 114), control: CGPoint(x: 128, y: 119))
                p.addQuadCurve(to: CGPoint(x: 118, y: 116), control: CGPoint(x: 133, y: 133))
                p.closeSubpath()
            }, color: ink, outline: false, in: context)
            line([(123, 119), (134, 118)], color: cream, width: 2, in: context)
        } else {
            stroke(path { p in
                p.move(to: CGPoint(x: 120, y: 118))
                p.addQuadCurve(to: CGPoint(x: 139, y: 115), control: CGPoint(x: 131, y: 125))
            }, color: ink, width: 2.3, in: context)
        }
        context.fill(Path(ellipseIn: CGRect(x: 100, y: 105, width: 10, height: 5)), with: .color(coral.opacity(0.3)))
        context.fill(Path(ellipseIn: CGRect(x: 145, y: 104, width: 9, height: 5)), with: .color(coral.opacity(0.3)))
    }

    private func cap(in context: GraphicsContext) {
        fill(path { p in
            p.move(to: CGPoint(x: 86, y: 70))
            p.addCurve(to: CGPoint(x: 162, y: 60), control1: CGPoint(x: 82, y: 20), control2: CGPoint(x: 151, y: 22))
            p.addLine(to: CGPoint(x: 164, y: 72))
            p.addQuadCurve(to: CGPoint(x: 86, y: 76), control: CGPoint(x: 123, y: 82))
            p.closeSubpath()
        }, color: cobalt, in: context)
        stroke(path { p in
            p.move(to: CGPoint(x: 125, y: 36))
            p.addQuadCurve(to: CGPoint(x: 135, y: 66), control: CGPoint(x: 135, y: 46))
        }, color: cream.opacity(0.4), width: 1.2, in: context)
        fill(path { p in
            p.move(to: CGPoint(x: 125, y: 69))
            p.addQuadCurve(to: CGPoint(x: 181, y: 72), control: CGPoint(x: 163, y: 62))
            p.addQuadCurve(to: CGPoint(x: 181, y: 82), control: CGPoint(x: 197, y: 78))
            p.addQuadCurve(to: CGPoint(x: 125, y: 69), control: CGPoint(x: 151, y: 85))
            p.closeSubpath()
        }, color: Color(hex: "#38329A"), in: context, width: 2.5)
        fill(Path(roundedRect: CGRect(x: 102, y: 50, width: 16, height: 14), cornerRadius: 3), color: cream, outline: false, in: context)
        line([(106, 54), (106, 60)], color: ink, width: 1.5, in: context)
        line([(110, 54), (110, 60)], color: ink, width: 1.5, in: context)
        line([(114, 54), (114, 60)], color: ink, width: 1.5, in: context)
        fill(Path(ellipseIn: CGRect(x: 119, y: 32, width: 8, height: 4)), color: cream, in: context, width: 1.3)
    }

    private func bandanaTails(in context: GraphicsContext) {
        fill(path { p in
            p.move(to: CGPoint(x: 88, y: 70))
            p.addQuadCurve(to: CGPoint(x: 61, y: 71), control: CGPoint(x: 70, y: 62))
            p.addLine(to: CGPoint(x: 69, y: 80))
            p.addLine(to: CGPoint(x: 55, y: 91))
            p.addQuadCurve(to: CGPoint(x: 87, y: 79), control: CGPoint(x: 77, y: 94))
            p.closeSubpath()
        }, color: coral, in: context, width: 2)
    }

    private func bandana(in context: GraphicsContext) {
        fill(path { p in
            p.move(to: CGPoint(x: 87, y: 67))
            p.addQuadCurve(to: CGPoint(x: 161, y: 65), control: CGPoint(x: 128, y: 62))
            p.addLine(to: CGPoint(x: 161, y: 79))
            p.addQuadCurve(to: CGPoint(x: 89, y: 80), control: CGPoint(x: 127, y: 75))
            p.closeSubpath()
        }, color: coral, in: context, width: 2)
        fill(Path(ellipseIn: CGRect(x: 81, y: 68, width: 13, height: 13)), color: coral, in: context, width: 1.5)
        for x: CGFloat in [105, 125, 145] {
            fill(path { p in
                p.move(to: CGPoint(x: x, y: 68))
                p.addLine(to: CGPoint(x: x + 3, y: 72))
                p.addLine(to: CGPoint(x: x, y: 75))
                p.addLine(to: CGPoint(x: x - 3, y: 72))
                p.closeSubpath()
            }, color: cream, outline: false, in: context)
        }
    }

    private func path(_ draw: (inout Path) -> Void) -> Path {
        var result = Path()
        draw(&result)
        return result
    }

    private func fill(_ path: Path, color: Color, outline: Bool = true, in context: GraphicsContext, width: CGFloat = 2.8) {
        context.fill(path, with: .color(color))
        if outline { stroke(path, color: ink, width: width, in: context) }
    }

    private func stroke(_ path: Path, color: Color, width: CGFloat, in context: GraphicsContext) {
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private func line(_ points: [(CGFloat, CGFloat)], color: Color, width: CGFloat, in context: GraphicsContext) {
        guard let first = points.first else { return }
        stroke(path { p in
            p.move(to: CGPoint(x: first.0, y: first.1))
            for point in points.dropFirst() { p.addLine(to: CGPoint(x: point.0, y: point.1)) }
        }, color: color, width: width, in: context)
    }

    private func text(_ string: String, at point: CGPoint, size: CGFloat, color: Color, in context: GraphicsContext) {
        context.draw(Text(verbatim: string).font(.system(size: size, weight: .black, design: .rounded)).foregroundColor(color), at: point)
    }
}

private struct DayVaultAvatarPreviews: PreviewProvider {
    static var previews: some View {
        HStack {
            DayVaultAvatar(animated: false)
            DayVaultAvatar(pose: .wave, animated: false)
        }
        .frame(height: 300)
        .background(EditorialPalette.paper)
    }
}
