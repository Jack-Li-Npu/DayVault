import DayVaultCore
import SwiftUI

struct VaultView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("vaultAppearance") private var vaultAppearanceRaw = VaultAppearance.obsidian.rawValue
    @State private var showsCollection = false
    @State private var showsPersonalAchievements = false

    init(showCollection: Bool = false, showPersonal: Bool = false) {
        _showsCollection = State(initialValue: showCollection)
        _showsPersonalAchievements = State(initialValue: showPersonal)
    }

    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 146), spacing: 10)]
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ZStack {
                vaultBackground.ignoresSafeArea()
                VaultPrintPattern(color: accent.opacity(showsCollection ? 0.06 : 0.025))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                VStack(spacing: 0) {
                    VaultScreenHeader()
                    HStack(spacing: 0) {
                        sectionButton("我的角色", collection: false)
                        sectionButton("成就册", collection: true)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if showsCollection {
                                HStack(spacing: 12) {
                                    collectionFilter("通用成就", personal: false)
                                    collectionFilter("我的里程碑", personal: true)
                                }
                                if showsPersonalAchievements {
                                    PersonalAchievementsView()
                                } else {
                                    header
                                    Text("vault.collection")
                                        .font(.caption.weight(.black))
                                        .tracking(1.6)
                                        .foregroundStyle(.white.opacity(0.55))
                                    LazyVGrid(columns: columns, spacing: 10) {
                                        ForEach(Array(AchievementCatalog.all.enumerated()), id: \.element.id) { index, definition in
                                            achievementCard(definition, index: index)
                                        }
                                    }
                                }
                            } else {
                                AvatarStudioView()
                            }
                        }
                        .padding(18)
                        .padding(.bottom, 28)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { model.historicalUnlockCount = 0 }
            .sheet(item: $model.vaultSelection) { definition in
                AchievementDetailView(definition: definition, accent: accent)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func collectionFilter(_ title: String, personal: Bool) -> some View {
        Button { showsPersonalAchievements = personal } label: {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(showsPersonalAchievements == personal ? Color.black : Color.white.opacity(0.7))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(showsPersonalAchievements == personal ? accent : .clear)
                .overlay { Rectangle().stroke(accent.opacity(0.4), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(personal ? "vault-personal-achievements" : "vault-public-achievements")
        .accessibilityAddTraits(showsPersonalAchievements == personal ? .isSelected : [])
    }

    private func sectionButton(_ title: String, collection: Bool) -> some View {
        Button { showsCollection = collection } label: {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(showsCollection == collection ? accent : .white.opacity(0.55))
                .frame(maxWidth: .infinity, minHeight: 46)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(showsCollection == collection ? accent : .white.opacity(0.15)).frame(height: 2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(showsCollection == collection ? .isSelected : [])
    }

    private var appearance: VaultAppearance {
        VaultAppearance(rawValue: vaultAppearanceRaw) ?? .obsidian
    }

    private var vaultBackground: Color {
        switch appearance {
        case .obsidian: EditorialPalette.vault
        case .nebula: Color(hex: "#191122")
        case .emerald: Color(hex: "#0E1B16")
        }
    }

    private var accent: Color {
        switch appearance {
        case .obsidian: EditorialPalette.acid
        case .nebula: Color(hex: "#E9A6FF")
        case .emerald: EditorialPalette.mint
        }
    }

    private var header: some View {
        let publicIDs = Set(AchievementCatalog.all.map(\.id))
        let unlocked = Set(model.achievementStates.filter { $0.unlockedAt != nil && publicIDs.contains($0.definitionID) }.map(\.definitionID)).count
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("vault.counter_label")
                        .font(.caption.monospaced().weight(.black))
                        .tracking(1.7)
                        .foregroundStyle(accent)
                    Text("vault.subtitle")
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(String(format: "%02d", unlocked))
                        .font(.system(size: 48, weight: .black, design: .monospaced))
                        .foregroundStyle(accent)
                    Text("/24")
                        .font(.caption.monospaced().weight(.bold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            HStack(spacing: 3) {
                ForEach(0..<AchievementCatalog.all.count, id: \.self) { index in
                    Rectangle()
                        .fill(index < unlocked ? accent : Color.white.opacity(0.12))
                        .frame(maxWidth: .infinity, minHeight: 7, maxHeight: 7)
                }
            }
            Text("vault.no_rarity_yet")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.52))
        }
        .padding(18)
        .background(EditorialPalette.vaultSheet)
        .overlay { Rectangle().stroke(Color.white.opacity(0.25), lineWidth: 1) }
        .background(accent.offset(x: 5, y: 5))
    }

    private func achievementCard(_ definition: AchievementDefinition, index: Int) -> some View {
        let state = model.achievementState(for: definition)
        let unlocked = state?.unlockedAt != nil
        return Button { model.vaultSelection = definition } label: {
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .top) {
                    AchievementBadge(definition: definition, unlocked: unlocked, progress: state?.progress ?? 0, size: 72)
                    Spacer(minLength: 5)
                    Text(String(format: "%02d", index + 1))
                        .font(.caption2.monospaced().weight(.black))
                        .foregroundStyle(.white.opacity(0.62))
                }
                Text(unlocked || !definition.isHidden ? LocalizedStringKey(definition.titleKey) : "vault.concealed")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                statusLine(definition: definition, state: state, unlocked: unlocked)
            }
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 152, alignment: .leading)
            .background(EditorialPalette.vaultSheet)
            .overlay { Rectangle().stroke(unlocked ? accent.opacity(0.8) : Color.white.opacity(0.14), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityTitle(definition, unlocked: unlocked))
        .accessibilityValue(accessibilityStatus(definition, state: state, unlocked: unlocked))
        .accessibilityHint("vault.open_detail")
    }

    @ViewBuilder
    private func statusLine(definition: AchievementDefinition, state: AchievementState?, unlocked: Bool) -> some View {
        if definition.isHidden && !unlocked {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(signalColor(state?.signal ?? .dormant))
                    .frame(width: 7, height: 7)
                Text(signalKey(state?.signal ?? .dormant))
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(signalColor(state?.signal ?? .dormant))
        } else {
            if unlocked {
                Text("vault.unlocked")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
            } else {
                Text(String(format: "%d%%", Int((state?.progress ?? 0) * 100)))
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private func signalKey(_ signal: HiddenSignal) -> LocalizedStringKey {
        LocalizedStringKey("signal.\(signal.rawValue)")
    }

    private func signalColor(_ signal: HiddenSignal) -> Color {
        switch signal {
        case .dormant: .white.opacity(0.62)
        case .faint: EditorialPalette.coral
        case .resonant: EditorialPalette.acid
        }
    }

    private func accessibilityTitle(_ definition: AchievementDefinition, unlocked: Bool) -> String {
        NSLocalizedString(
            unlocked || !definition.isHidden ? definition.titleKey : "vault.concealed",
            comment: ""
        )
    }

    private func accessibilityStatus(
        _ definition: AchievementDefinition,
        state: AchievementState?,
        unlocked: Bool
    ) -> String {
        if unlocked { return NSLocalizedString("vault.unlocked", comment: "") }
        if definition.isHidden {
            return NSLocalizedString("signal.\((state?.signal ?? .dormant).rawValue)", comment: "")
        }
        return String(
            format: NSLocalizedString("vault.progress_value", comment: ""),
            Int((state?.progress ?? 0) * 100)
        )
    }
}

private struct VaultScreenHeader: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("vault.index")
                    .font(.caption2.monospaced().weight(.black))
                    .tracking(1.4)
                    .foregroundStyle(EditorialPalette.acid)
                Text("vault.title")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(.leading, 18)
        .padding(.trailing, 70)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}

private struct VaultPrintPattern: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 32
            var x: CGFloat = 0
            while x < size.width {
                context.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)), with: .color(color))
                x += step
            }
            var y: CGFloat = 0
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(color))
                y += step
            }
        }
    }
}

private struct AchievementDetailView: View {
    @Environment(AppModel.self) private var model
    @State private var showsEquipmentReplay = false
    let definition: AchievementDefinition
    let accent: Color

    private var reward: AvatarReward? { AvatarRewardCatalog.reward(for: definition.id) }

    var body: some View {
        let state = model.achievementState(for: definition)
        let unlocked = state?.unlockedAt != nil
        ZStack {
            EditorialPalette.vault.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        AchievementBadge(definition: definition, unlocked: unlocked, progress: state?.progress ?? 0, size: 118)
                        Spacer()
                        Text("vault.detail_code")
                            .font(.caption2.monospaced().weight(.black))
                            .tracking(1.3)
                            .foregroundStyle(accent)
                    }
                    Text(unlocked || !definition.isHidden ? LocalizedStringKey(definition.titleKey) : "vault.concealed")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .foregroundStyle(.white)
                    Rectangle().fill(accent).frame(width: 54, height: 5)
                    if definition.isHidden && !unlocked {
                        Text(LocalizedStringKey("signal.\((state?.signal ?? .dormant).rawValue)"))
                            .font(.headline.weight(.black))
                            .foregroundStyle(accent)
                        if state?.signal == .resonant, let clue = definition.clueKey {
                            Text(LocalizedStringKey(clue))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.78))
                        } else {
                            Text("vault.hidden_keep_going")
                                .foregroundStyle(.white.opacity(0.68))
                        }
                    } else {
                        Text(LocalizedStringKey(definition.descriptionKey))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    if let date = state?.unlockedAt {
                        Text(date, format: .dateTime.year().month().day())
                            .font(.caption.monospacedDigit().weight(.black))
                            .foregroundStyle(accent)
                        if reward != nil {
                            Button("查看装备演出") { showsEquipmentReplay = true }
                                .buttonStyle(AvatarOutlineButtonStyle())
                                .accessibilityIdentifier("achievement-replay-equipment")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(28)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showsEquipmentReplay) {
            if let reward {
                AvatarUnlockCeremony(reward: reward, isPreview: true) { showsEquipmentReplay = false }
            }
        }
    }
}
