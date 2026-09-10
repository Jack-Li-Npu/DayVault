import AudioToolbox
import DayVaultCore
import SwiftUI
import UIKit

struct AvatarUnlockCeremony: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.avatarReducedMotionPreview) private var previewReduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    let reward: AvatarReward
    var isPreview = false
    let finish: () -> Void

    @State private var phase = 0

    private var ready: Bool { phase >= 3 }
    private var reduceMotion: Bool { systemReduceMotion || previewReduceMotion }
    private var recordCount: Int {
        isPreview ? 10 : min(12, model.logs.filter { $0.status == .completed }.count)
    }
    private var canEquip: Bool { !isPreview && model.unlockedAchievementIDs.contains(reward.achievementID) }
    private var outfit: AvatarOutfit {
        guard phase >= 2 || reduceMotion else { return model.avatarOutfit }
        return model.avatarOutfit.equipping(reward, unlockedAchievementIDs: model.unlockedAchievementIDs.union([reward.achievementID]))
    }

    var body: some View {
        ZStack {
            Color(hex: "#11110F").ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        Text(isPreview ? "演出预览 / 不会获得装备" : "新装备 / 来自你的日常")
                            .font(.caption.monospaced().weight(.bold))
                            .foregroundStyle(EditorialPalette.acid)
                        Spacer()
                        Button(action: finish) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .bold))
                                .frame(width: 44, height: 44)
                                .overlay { Circle().stroke(.white.opacity(0.3), lineWidth: 1) }
                        }
                        .accessibilityLabel(isPreview ? "关闭预览" : "稍后穿戴")
                        .accessibilityIdentifier("avatar-ceremony-close")
                    }

                    VStack(spacing: 7) {
                        Text(ready ? "穿上这段经历。" : "每一次，都算数。")
                            .font(.system(.largeTitle, design: .rounded, weight: .black))
                            .multilineTextAlignment(.center)
                            .contentTransition(.opacity)
                        Text(isPreview ? "回看：\(reward.name)" : "你获得了一件新的成就装备")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .accessibilityElement(children: .combine)

                    ZStack {
                        AvatarDisplayStage(outfit: outfit, pose: ready ? .proud : .idle, animated: !reduceMotion)
                        if !reduceMotion {
                            HStack(spacing: 5) {
                                ForEach(0..<recordCount, id: \.self) { index in
                                    Text(String(format: "%02d", index + 1))
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color(hex: "#171714"))
                                        .frame(width: phase >= 2 ? 3 : 20, height: phase >= 2 ? 6 : 25)
                                        .background(EditorialPalette.acid)
                                        .clipped()
                                }
                            }
                            .scaleEffect(phase >= 2 ? 0.2 : 1)
                            .offset(y: phase >= 2 ? 20 : 145)
                            .opacity(phase == 1 ? 1 : 0)
                            .accessibilityHidden(true)
                            AvatarStitchTrail()
                                .trim(from: phase >= 2 ? 1 : 0, to: phase >= 1 ? 1 : 0)
                                .stroke(EditorialPalette.coral, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [5, 5]))
                                .padding(26)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(height: 340)
                    .scaleEffect(phase == 0 && !reduceMotion ? 0.94 : 1)
                    .rotationEffect(.degrees(phase == 2 && !reduceMotion ? -2 : 0))
                    .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        Text(reward.name)
                            .font(.title.weight(.black))
                            .foregroundStyle(EditorialPalette.acid)
                        if let definition = AchievementCatalog.all.first(where: { $0.id == reward.achievementID }) {
                            Text(LocalizedStringKey(definition.descriptionKey))
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        if isPreview {
                            Text("这里使用示例进度，你的记录和穿搭不会改变。")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.55))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .opacity(ready || reduceMotion ? 1 : 0.35)

                    if ready {
                        Button(isPreview ? "返回我的角色" : "穿上，继续出发") {
                            if canEquip { model.equipAvatarReward(reward.id) }
                            finish()
                        }
                        .buttonStyle(EditorialPrimaryButtonStyle(fill: EditorialPalette.acid, foreground: .black))
                        .accessibilityIdentifier("avatar-ceremony-continue")
                        if !isPreview {
                            Button("先收进衣橱", action: finish)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(minHeight: 44)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 26)
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .accessibilityAddTraits(.isModal)
        .task { await play() }
    }

    @MainActor
    private func play() async {
        guard !reduceMotion else {
            withAnimation(.easeOut(duration: 0.2)) { phase = 3 }
            announce()
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(180))
            withAnimation(.easeOut(duration: 0.8)) { phase = 1 }
            try await Task.sleep(for: .milliseconds(850))
            withAnimation(.spring(response: 0.55, dampingFraction: 0.76)) { phase = 2 }
            try await Task.sleep(for: .milliseconds(800))
            withAnimation(.easeInOut(duration: 0.4)) { phase = 3 }
            if !isPreview {
                if UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                if UserDefaults.standard.bool(forKey: "achievementSoundEnabled") {
                    AudioServicesPlaySystemSound(1104)
                }
            }
            announce()
        } catch {
            // Leaving the ceremony cancels its pending phases and feedback.
        }
    }

    private func announce() {
        guard voiceOverEnabled else { return }
        UIAccessibility.post(notification: .announcement, argument: isPreview ? "演出预览。没有获得装备。" : "已获得\(reward.name)，可以穿上或收进衣橱。")
    }
}

private struct AvatarStitchTrail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.83))
        path.addCurve(to: CGPoint(x: rect.maxX * 0.7, y: rect.maxY * 0.6),
                      control1: CGPoint(x: rect.minX, y: rect.maxY * 0.35),
                      control2: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.maxX * 0.3, y: rect.maxY * 0.34),
                      control1: CGPoint(x: rect.maxX * 0.25, y: rect.maxY * 0.1),
                      control2: CGPoint(x: rect.maxX * 0.1, y: rect.maxY * 0.9))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.12),
                      control1: CGPoint(x: rect.maxX * 0.9, y: rect.maxY * 0.65),
                      control2: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}
