import DayVaultCore
import SwiftUI
import UIKit

/// The studio only saves earned outfits. Trying something on never changes the model.
struct AvatarStudioView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.avatarReducedMotionPreview) private var previewReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var wardrobeOpen = false
    @State private var pose = AvatarPose.idle
    @State private var share: AvatarShareImage?
    @State private var shareFailed = false
    @State private var previewCeremony = false

    private var completionCount: Int { model.logs.filter { $0.status == .completed }.count }
    private var reduceMotion: Bool { systemReduceMotion || previewReduceMotion }

    var body: some View {
        let headerLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        let actionLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))
        let footerLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
        VStack(alignment: .leading, spacing: 22) {
            headerLayout {
                Text("角色档案")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                Text("\(model.earnedAvatarRewards.count) / 6 件")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(EditorialPalette.acid)
            }

            VStack(alignment: .leading, spacing: 0) {
                AvatarDisplayStage(outfit: model.avatarOutfit, pose: pose)
                    .frame(height: 300)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("累计完成记录")
                            .font(.caption2.weight(.medium))
                        Text("已完成 \(completionCount) 件事")
                            .font(.subheadline.weight(.black))
                    }
                    .foregroundStyle(Color(hex: "#171714"))
                    .padding(18)
            }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#EEE9DC"))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("我的角色，已完成\(completionCount)件事，穿戴\(model.avatarOutfit.equippedIDs.count)件成就装备")
                .accessibilityIdentifier("avatar-current-character")

            actionLayout {
                Button("切换姿态", action: changePose)
                    .buttonStyle(AvatarOutlineButtonStyle())
                    .accessibilityIdentifier("avatar-change-pose")
                Button(action: renderShareCard) {
                    Label("分享形象", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(AvatarOutlineButtonStyle())
                .accessibilityIdentifier("avatar-share")
            }

            Button { wardrobeOpen = true } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("我的衣橱").font(.title3.weight(.black))
                        Text(model.earnedAvatarRewards.isEmpty ? "首次完成事项可解锁启程护腕。" : "查看已获装备及解锁条件。")
                            .font(.caption)
                    }
                    Spacer(minLength: 8)
                    Text("↗").font(.title.weight(.bold))
                }
                .foregroundStyle(Color(hex: "#171714"))
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(EditorialPalette.acid)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("avatar-open-wardrobe")

            footerLayout {
                Text("装备来自日常成就。\n短暂停下，也不会失去已获得的装备。")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                Button("预览解锁动画") { previewCeremony = true }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EditorialPalette.acid)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("avatar-preview-ceremony")
            }
        }
        .sheet(isPresented: $wardrobeOpen) {
            AvatarWardrobeView()
                .dynamicTypeSize(dynamicTypeSize)
        }
        .sheet(item: $share) { image in
            AvatarShareSheet(image: image.image)
        }
        .fullScreenCover(isPresented: $previewCeremony) {
            if let reward = AvatarRewardCatalog.all.first(where: { $0.id == "ten_jacket" }) {
                AvatarUnlockCeremony(reward: reward, isPreview: true) { previewCeremony = false }
                    .dynamicTypeSize(dynamicTypeSize)
                    .environment(\.avatarReducedMotionPreview, previewReduceMotion)
            }
        }
        .alert("分享卡暂时没有生成", isPresented: $shareFailed) {
            Button("重试", action: renderShareCard)
            Button("返回", role: .cancel) {}
        } message: {
            Text("你的穿搭已保留，可以稍后再试。")
        }
    }

    private func changePose() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.72)) {
            switch pose {
            case .idle: pose = .wave
            case .wave: pose = .proud
            case .proud: pose = .celebrate
            case .celebrate: pose = .idle
            }
        }
    }

    @MainActor
    private func renderShareCard() {
        let rewards = model.earnedAvatarRewards.filter { model.avatarOutfit.equippedIDs.contains($0.id) }
        let renderer = ImageRenderer(content: AvatarShareCard(
            outfit: model.avatarOutfit,
            completionCount: completionCount,
            equipment: rewards.map(\.name)
        ))
        renderer.scale = 3
        guard let image = renderer.uiImage else {
            shareFailed = true
            return
        }
        share = AvatarShareImage(image: image)
    }
}

struct AvatarDisplayStage: View {
    var outfit: AvatarOutfit
    var pose: AvatarPose = .idle
    var animated = true
    var showsCaption = true

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width * 0.7, geometry.size.height * 0.7)
            ZStack {
                Color(hex: "#EEE9DC")
                Circle()
                    .fill(Color(hex: "#E4DDBE"))
                    .frame(width: diameter, height: diameter)
                    .offset(y: -6)
                Circle()
                    .stroke(Color(hex: "#171714").opacity(0.13), lineWidth: 1)
                    .frame(width: diameter * 1.15, height: diameter * 1.15)
                    .offset(y: -6)
                if showsCaption {
                    VStack {
                        HStack {
                            Text("DV / 人物档案")
                            Spacer()
                            Text("日常养成")
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(Color(hex: "#676355"))
                        Spacer()
                    }
                    .padding(18)
                }
                DayVaultAvatar(outfit: outfit, pose: pose, animated: animated)
                    .frame(width: min(max(geometry.size.width - 12, 1), 260), height: max(1, geometry.size.height - (showsCaption ? 54 : 10)))
                    .offset(y: -5)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .clipped()
    }
}

private struct AvatarWardrobeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selected: AvatarReward?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("成就装备")
                        .font(.title2.weight(.black))
                    Text("选择装备查看解锁条件。未获得的装备仅可预览，解锁后可保存穿搭。")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AvatarRewardCatalog.all) { reward in
                            rewardCard(reward)
                        }
                    }
                    Text("穿搭保存在本机；装备资格随已解锁成就恢复。")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(18)
            }
            .background(EditorialPalette.vault)
            .navigationTitle("我的衣橱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .tint(EditorialPalette.acid)
                        .accessibilityIdentifier("avatar-wardrobe-close")
                }
            }
            .sheet(item: $selected) { reward in
                AvatarRewardDetailView(reward: reward)
                    .dynamicTypeSize(dynamicTypeSize)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 260 : 145), spacing: 12)]
    }

    private func rewardCard(_ reward: AvatarReward) -> some View {
        let earned = model.unlockedAchievementIDs.contains(reward.achievementID)
        let concealed = avatarRewardIsConcealed(reward, earned: earned)
        let equipped = model.avatarOutfit.equippedIDs.contains(reward.id)
        return Button { selected = reward } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    if concealed {
                        ZStack {
                            Color(hex: "#292A22")
                            Text("?").font(.system(size: 72, weight: .black, design: .monospaced))
                                .foregroundStyle(EditorialPalette.acid.opacity(0.6))
                        }
                        .frame(height: 150)
                    } else {
                        AvatarDisplayStage(outfit: AvatarOutfit().equipping(reward, unlockedAchievementIDs: [reward.achievementID]), animated: false, showsCaption: false)
                            .frame(height: 150)
                    }
                    if equipped {
                        Text("穿戴中")
                            .font(.caption2.weight(.black))
                            .padding(6)
                            .foregroundStyle(Color.black)
                            .background(EditorialPalette.acid)
                    }
                }
                Text(concealed ? "隐藏装备" : reward.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(earned ? "已获得 · 查看解锁记录" : concealed ? "尚未解锁" : "未获得 · 可以试穿")
                    .font(.caption2)
                    .foregroundStyle(earned ? EditorialPalette.acid : .white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(EditorialPalette.vaultSheet)
            .overlay { Rectangle().stroke(equipped ? EditorialPalette.acid : .white.opacity(0.15), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("avatar-reward-\(reward.id)")
        .accessibilityLabel(concealed ? "隐藏装备，尚未获得" : "\(reward.name)，\(equipped ? "穿戴中" : earned ? "已获得" : "未获得，可以试穿")")
    }
}

private struct AvatarRewardDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let reward: AvatarReward

    private var earned: Bool { model.unlockedAchievementIDs.contains(reward.achievementID) }
    private var concealed: Bool { avatarRewardIsConcealed(reward, earned: earned) }
    private var equipped: Bool { model.avatarOutfit.equippedIDs.contains(reward.id) }
    private var definition: AchievementDefinition? { AchievementCatalog.all.first { $0.id == reward.achievementID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if concealed {
                        Text("?")
                            .font(.system(size: 100, weight: .black, design: .monospaced))
                            .frame(maxWidth: .infinity, minHeight: 210)
                            .background(EditorialPalette.vaultSheet)
                        Text("隐藏装备").font(.title.weight(.black))
                        Text("隐藏装备，解锁后显示详情。")
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        AvatarDisplayStage(
                            outfit: model.avatarOutfit.equipping(reward, unlockedAchievementIDs: model.unlockedAchievementIDs.union([reward.achievementID])),
                            pose: .proud
                        )
                        .frame(height: 300)
                        Text(reward.name).font(.title.weight(.black))
                        Text(reward.detail).font(.subheadline).foregroundStyle(.white.opacity(0.7))
                        if let definition {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(earned ? "这件装备的来历" : "获得方式")
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(EditorialPalette.acid)
                                Text(LocalizedStringKey(definition.descriptionKey))
                                    .font(.body.weight(.semibold))
                                if let date = model.achievementState(for: definition)?.unlockedAt {
                                    Text("获得于 \(date.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_CN"))))")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.white.opacity(0.65))
                                } else {
                                    let progress = model.achievementState(for: definition)?.progress ?? 0
                                    ProgressView(value: progress).tint(EditorialPalette.acid)
                                    Text("已完成 \(Int(progress * 100))%")
                                        .font(.caption.monospacedDigit())
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(EditorialPalette.vaultSheet)
                        }
                        if earned {
                            Button(equipped ? "脱下这件" : "穿上这件") {
                                if equipped { model.removeAvatarReward(in: reward.slot) }
                                else { model.equipAvatarReward(reward.id) }
                                dismiss()
                            }
                            .buttonStyle(EditorialPrimaryButtonStyle(fill: EditorialPalette.acid, foreground: .black))
                            .accessibilityIdentifier("avatar-equip-reward")
                        } else {
                            Text("试穿效果 · 尚未获得，不会保存到穿搭")
                                .font(.caption)
                                .foregroundStyle(EditorialPalette.acid)
                                .accessibilityIdentifier("avatar-preview-only")
                        }
                    }
                }
                .padding(20)
            }
            .background(EditorialPalette.vault)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("返回") { dismiss() }
                        .tint(EditorialPalette.acid)
                        .accessibilityIdentifier("avatar-reward-detail-close")
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private func avatarRewardIsConcealed(_ reward: AvatarReward, earned: Bool) -> Bool {
    !earned && AchievementCatalog.all.first(where: { $0.id == reward.achievementID })?.isHidden == true
}

struct AvatarOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(configuration.isPressed ? Color.white.opacity(0.12) : .clear)
            .overlay { Rectangle().stroke(Color.white.opacity(0.3), lineWidth: 1) }
    }
}

private struct AvatarShareCard: View {
    let outfit: AvatarOutfit
    let completionCount: Int
    let equipment: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("DAYVAULT").tracking(3)
                Spacer()
                Text("我的日常档案")
            }
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            AvatarDisplayStage(outfit: outfit, pose: .proud, animated: false)
                .frame(height: 320)
            Text("个人成就记录")
                .font(.system(size: 23, weight: .black))
            Text("已完成 \(completionCount) 件事")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(EditorialPalette.acid)
            Text(equipment.isEmpty ? "暂无成就装备" : equipment.joined(separator: " / "))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            Text("依据 DayVault 中的个人记录 · \(Date().formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_CN"))))")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(24)
        .frame(width: 390)
        .foregroundStyle(.white)
        .background(Color(hex: "#11110F"))
        .environment(\.colorScheme, .dark)
    }
}

private struct AvatarShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct AvatarShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
