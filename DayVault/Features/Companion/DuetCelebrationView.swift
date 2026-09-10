import DayVaultCore
import SwiftUI

/// A replayable six-second performance. It never awards progress or changes an outfit.
struct DuetCelebrationView: View {
    var outfit: AvatarOutfit
    var companionDays: Int
    var isPreview = false
    let finish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.avatarReducedMotionPreview) private var previewReduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt = Date()
    @State private var playbackID = UUID()
    @State private var ended = false

    private var reduceMotion: Bool { systemReduceMotion || previewReduceMotion }
    private var stage: Int {
        if companionDays >= 30 { return 2 }
        if companionDays >= 7 { return 1 }
        return 0
    }
    private var title: String {
        switch stage {
        case 0: "这一招，还在磨合。"
        case 1: "这次，接上了。"
        default: "这一招，配合得不错。"
        }
    }

    var body: some View {
        ZStack {
            EditorialPalette.paper.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Text(isPreview ? "双人片段 · 回看" : "留住这一刻")
                            .font(.caption.monospaced().weight(.bold))
                            .foregroundStyle(EditorialPalette.muted)
                        Spacer()
                        Button(ended || reduceMotion ? "关闭" : "跳过", action: finish)
                            .font(.subheadline.weight(.bold))
                            .frame(minWidth: 60, minHeight: 44)
                            .accessibilityIdentifier("duet-skip")
                    }
                    Spacer(minLength: 8)
                    Text(title)
                        .font(.system(.title, design: .rounded, weight: .black))
                        .multilineTextAlignment(.center)
                    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: ended || reduceMotion || scenePhase != .active)) {
                        timeline in
                        let progress = reduceMotion || ended ? 6 : min(6, max(0, timeline.date.timeIntervalSince(startedAt)))
                        scene(at: progress)
                    }
                    .frame(height: 310)
                    .background(Color(hex: "#EEE9DC"))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("你的角色与折纸伙伴配合庆祝。回看不增加进度。")
                    Text(companionDays == 0 ? "从第一次记录开始，慢慢配合。" : "\(companionDays) 个有记录的日子，留下了现在的默契。")
                        .font(.subheadline)
                        .foregroundStyle(EditorialPalette.muted)
                        .multilineTextAlignment(.center)
                    if ended || reduceMotion {
                        Button("继续今天", action: finish)
                            .buttonStyle(
                                EditorialPrimaryButtonStyle(fill: EditorialPalette.acid, foreground: Color(hex: "#171714"))
                            )
                            .accessibilityIdentifier("duet-continue")
                        if !reduceMotion {
                            Button("再看一次", action: replay)
                                .font(.subheadline.weight(.bold))
                                .frame(minHeight: 44)
                                .accessibilityIdentifier("duet-replay")
                        }
                    } else {
                        Color.clear.frame(height: 100)
                            .accessibilityHidden(true)
                    }
                    Spacer(minLength: 8)
                }
                .padding(24)
                .foregroundStyle(EditorialPalette.ink)
            }
        }
        .task(id: playbackID) {
            guard !reduceMotion else {
                ended = true
                return
            }
            do {
                try await Task.sleep(for: .seconds(6))
                ended = true
            } catch {}
        }
    }

    private func scene(at time: Double) -> some View {
        let climax = time >= 3.3
        let settled = time >= 5.1
        let contact = time >= 1.7 && time < 2.2
        let charge = min(1, max(0, (time - 2.3) / 0.8))
        let launch = min(1, max(0, (time - 3.3) / 0.6))
        let leap = sin(min(1, max(0, (time - 0.8) / 2)) * .pi)
        let bounce = reduceMotion ? 0 : leap * (stage == 0 ? 78 : 108)
        let approach = reduceMotion ? 0 : leap * (stage == 0 ? 29 : 45)
        let buddyScale = reduceMotion ? 1 : 1 + charge * (stage == 2 ? 0.35 : 0.16) * (settled ? 0 : 1)
        let userPose: AvatarPose
        if settled { userPose = .proud } else if climax { userPose = .celebrate } else { userPose = .wave }
        let buddyRotation: Double
        if reduceMotion || settled {
            buddyRotation = 0
        } else if stage == 0 && contact {
            buddyRotation = 16
        } else {
            buddyRotation = -launch * 12
        }
        return GeometryReader { geometry in
            ZStack {
                Circle()
                    .fill(EditorialPalette.acid.opacity(0.5))
                    .frame(width: 220, height: 220)
                    .offset(y: 15)
                Rectangle()
                    .fill(Color(hex: "#24291F").opacity(0.15))
                    .frame(height: 1)
                    .offset(y: 126)
                DayVaultAvatar(outfit: outfit, pose: userPose, animated: !reduceMotion && !ended)
                    .frame(width: 210, height: 280)
                    .offset(x: -geometry.size.width * 0.17, y: 4)
                OrigamiCompanion(days: companionDays, isCelebrating: climax && !settled, animated: !reduceMotion && !ended)
                    .frame(width: 135, height: 135)
                    .scaleEffect(buddyScale)
                    .rotationEffect(.degrees(buddyRotation))
                    .offset(
                        x: geometry.size.width * 0.2 - approach - charge * 12,
                        y: 60 - bounce - (climax && !settled ? launch * 26 : 0))
                if contact && !reduceMotion {
                    Text(stage == 0 ? "…" : "啪")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .rotationEffect(.degrees(-12))
                        .offset(x: 20, y: -22)
                        .accessibilityHidden(true)
                }
                if climax && !settled && !reduceMotion {
                    Text(stage == 2 ? "合 拍 !" : "接 住 !")
                        .font(.system(size: stage == 2 ? 35 : 28, weight: .black, design: .rounded))
                        .foregroundStyle(EditorialPalette.cobalt)
                        .rotationEffect(.degrees(-8))
                        .scaleEffect(0.8 + launch * 0.2)
                        .offset(y: -107)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func replay() {
        startedAt = Date()
        ended = false
        playbackID = UUID()
    }
}
