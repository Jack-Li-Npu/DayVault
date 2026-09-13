import DayVaultCore
import SwiftUI

struct RootTabView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.avatarReducedMotionPreview) private var previewReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var activeScreen: SecondaryScreen?
    @State private var homeSheet: HomeSheet?
    @State private var opensCollection = false
    @State private var opensPersonalCollection = false
    @AppStorage("accentHex") private var accentHex = "#4F46E5"

    init() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let marker = arguments.firstIndex(of: "-preview-screen"),
           arguments.indices.contains(marker + 1),
           let screen = SecondaryScreen(rawValue: arguments[marker + 1]), screen != .today {
            _activeScreen = State(initialValue: screen)
        }
#endif
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            today
            if activeScreen == nil && homeSheet == nil && !model.isPresentingEditor { unlockSummary }
        }
        .sheet(isPresented: Binding(
            get: { model.isPresentingEditor && activeScreen == nil },
            set: { model.isPresentingEditor = $0 }
        )) { ItemEditorView(initialDate: model.editorDate) }
        .sheet(item: $homeSheet) { sheet in
            homeSheetView(sheet)
                .dynamicTypeSize(dynamicTypeSize)
                .environment(\.avatarReducedMotionPreview, previewReduceMotion)
        }
        .fullScreenCover(item: $activeScreen) { screen in
            secondaryView(screen)
                .dynamicTypeSize(dynamicTypeSize)
                .environment(\.avatarReducedMotionPreview, previewReduceMotion)
        }
        .tint(Color(hex: accentHex))
        .onAppear {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-preview-editor") { model.showEditor() }
#endif
        }
        .onOpenURL { url in
            switch url.host {
            case "today": activeScreen = nil
            case "calendar": activeScreen = .calendar
            case "vault":
                clearUnlockSummary()
                activeScreen = .vault
            case "insights": activeScreen = .insights
            default: break
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.3), value: unlockCount)
    }

    private var today: some View {
        TodayView(
            openVault: {
                clearUnlockSummary()
                opensCollection = false
                opensPersonalCollection = false
                activeScreen = .vault
            },
            openPlanner: { homeSheet = .planner },
            openCompanion: { homeSheet = .companion },
            openGoals: { homeSheet = .goals },
            openCalendar: { activeScreen = .calendar },
            openInsights: { activeScreen = .insights },
            openSettings: { activeScreen = .settings }
        )
    }

    @ViewBuilder
    private func homeSheetView(_ sheet: HomeSheet) -> some View {
        switch sheet {
        case .companion: CompanionSheet(goalID: model.selectedGoalID)
        case .goals: GoalManagerView()
        case .planner:
            NavigationStack {
                AILandingView(
                    openVault: { homeSheet = nil },
                    openToday: { homeSheet = nil },
                    openCalendar: { homeSheet = nil },
                    openInsights: { homeSheet = nil },
                    openSettings: { homeSheet = nil },
                    showsNavigationHeader: false
                )
                .safeAreaInset(edge: .top, spacing: 0) {
                    HStack {
                        Text("landing.kicker").font(.headline.weight(.bold))
                        Spacer()
                        Button("返回") { homeSheet = nil }
                            .font(.subheadline.weight(.bold))
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier("planner-close")
                    }
                    .padding(.horizontal, 20)
                    .background(EditorialPalette.paper)
                }
            }
        }
    }

    private var unlockCount: Int { model.unlockQueue.count + Set(model.personalUnlockIDs).count }

    @ViewBuilder
    private var unlockSummary: some View {
        if model.unlockBlockingSheets.isEmpty, unlockCount > 0 {
            HStack(spacing: 12) {
                Button {
                    opensCollection = true
                    opensPersonalCollection = model.unlockQueue.isEmpty && !model.personalUnlockIDs.isEmpty
                    clearUnlockSummary()
                    activeScreen = .vault
                } label: {
                    HStack(spacing: 12) {
                        Text("✦")
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(EditorialPalette.acid)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(unlockCount == 1 ? "新成就，收下了。" : "收下了 \(unlockCount) 项新成就。")
                                .font(.subheadline.weight(.bold))
                            Text("查看成就册")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer(minLength: 4)
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("achievement-summary-open")
                Button(action: clearUnlockSummary) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("收起成就提示")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .padding(12)
            .background(EditorialPalette.vaultSheet)
            .overlay { Rectangle().stroke(EditorialPalette.acid.opacity(0.7), lineWidth: 1) }
            .padding(.horizontal, 18)
            .padding(.bottom, 82)
            .transition(.opacity)
            .task(id: unlockCount) {
                guard !voiceOverEnabled else { return }
                do {
                    try await Task.sleep(for: .seconds(4))
                    clearUnlockSummary()
                } catch { }
            }
        }
    }

    private func clearUnlockSummary() {
        while !model.unlockQueue.isEmpty { model.consumeUnlock() }
        model.personalUnlockIDs.removeAll()
    }

    private func secondaryView(_ screen: SecondaryScreen) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch screen {
                case .today: today
                case .calendar: CalendarScreen()
                case .vault: VaultView(showCollection: opensCollection, showPersonal: opensPersonalCollection)
                case .insights: InsightsView()
                case .settings: SettingsView()
                }
            }
            Button { activeScreen = nil } label: {
                Text("×")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(EditorialPalette.ink)
                    .frame(width: 44, height: 44)
                    .background(EditorialPalette.paper)
                    .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
            }
            .padding(.trailing, 14)
            .padding(.top, 8)
            .accessibilityLabel("action.close")
        }
        .overlay(alignment: .bottom) {
            if screen != .vault && !model.isPresentingEditor { unlockSummary }
        }
        .sheet(isPresented: Binding(
            get: { model.isPresentingEditor },
            set: { model.isPresentingEditor = $0 }
        )) { ItemEditorView(initialDate: model.editorDate) }
    }
}

private enum SecondaryScreen: String, Identifiable {
    case today, calendar, vault, insights, settings
    var id: String { rawValue }
}

private enum HomeSheet: String, Identifiable {
    case planner, companion, goals
    var id: String { rawValue }
}
