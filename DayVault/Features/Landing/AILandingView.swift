import DayVaultCore
import SwiftUI

struct AILandingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var composerFocused: Bool

    let openVault: () -> Void
    let openToday: () -> Void
    let openCalendar: () -> Void
    let openInsights: () -> Void
    let openSettings: () -> Void
    var showsNavigationHeader = true

    @State private var input = ""
    @State private var originalGoal: String?
    @State private var clarificationQuestion: String?
    @State private var draft: GeneratedProjectPlan?
    @State private var isGenerating = false
    @State private var generationStage = 0
    @State private var errorMessage: String?
    @State private var appliedPlanTitle: String?
    @State private var showAllBlocks = false
    @State private var resultSource: AIPlannerSource?
    @State private var lastSubmission: String?

    private let generationMessages: [LocalizedStringKey] = [
        "ai.generating.milestones",
        "ai.generating.space",
        "ai.generating.steps",
    ]

    var body: some View {
        ZStack {
            EditorialBackdrop()
            VStack(spacing: 0) {
                if showsNavigationHeader { landingHeader }
                ScrollView {
                    VStack(spacing: 24) {
                        if isIdle {
                            Spacer(minLength: 34)
                            Button(action: openVault) {
                                DayVaultAvatar(outfit: model.avatarOutfit)
                                    .frame(width: 92, height: 106)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("我的角色与成就")
                            .accessibilityIdentifier("landing-avatar")
                            VStack(spacing: 9) {
                                Text("landing.kicker")
                                    .font(.caption.weight(.black))
                                    .tracking(1.8)
                                    .foregroundStyle(EditorialPalette.coralText)
                                Text("landing.question")
                                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                                    .foregroundStyle(EditorialPalette.ink)
                                    .multilineTextAlignment(.center)
                                Text("landing.subtitle")
                                    .font(.subheadline)
                                    .foregroundStyle(EditorialPalette.muted)
                                    .multilineTextAlignment(.center)
                            }
                            centralComposer
                            challengeSection
                        } else {
                            conversationContent
                        }
                    }
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.bottom, isIdle ? 34 : 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isIdle { bottomComposer }
        }
        .alert("ai.error.title", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("action.retry") {
                if let lastSubmission { input = lastSubmission; submit() }
            }
            Button("action.cancel", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .animation(reduceMotion ? nil : .spring(response: 0.40, dampingFraction: 0.86), value: draft?.id)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isGenerating)
    }

    private var isIdle: Bool {
        originalGoal == nil && draft == nil && !isGenerating && clarificationQuestion == nil
    }

    private var landingHeader: some View {
        HStack(spacing: 10) {
            Button(action: openVault) {
                DayVaultMark(size: 30)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("landing.open_vault")
            Text("brand.wordmark")
                .font(.caption.monospaced().weight(.black))
                .tracking(1.2)
                .foregroundStyle(EditorialPalette.ink)
            Spacer()
            Menu {
                Button("today.title", systemImage: "checklist", action: openToday)
                Button("calendar.title", systemImage: "calendar", action: openCalendar)
                Button("insights.title", systemImage: "chart.bar.xaxis", action: openInsights)
                Button("action.add_manual", systemImage: "plus.square") { model.showEditor() }
                Divider()
                Button("settings.title", systemImage: "gearshape", action: openSettings)
            } label: {
                EditorialMenuGlyph()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("landing.profile_menu")
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .overlay(alignment: .bottom) {
            Rectangle().fill(EditorialPalette.rule).frame(height: 1)
                .padding(.horizontal, 18)
        }
    }

    private var centralComposer: some View {
        VStack(spacing: 9) {
            ComposerField(text: $input, focused: $composerFocused, isBusy: isGenerating, submit: submit)
            if !AIPlannerServiceFactory.isRemoteConfigured {
                HStack(spacing: 6) {
                    Rectangle().fill(EditorialPalette.mint).frame(width: 7, height: 7)
                    Text("ai.local_preview")
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(EditorialPalette.muted)
            }
        }
    }

    private var bottomComposer: some View {
        VStack(spacing: 6) {
            if draft != nil {
                Text("ai.adjust_hint")
                    .font(.caption)
                    .foregroundStyle(EditorialPalette.muted)
            }
            ComposerField(text: $input, focused: $composerFocused, isBusy: isGenerating, submit: submit)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(EditorialPalette.paper)
        .overlay(alignment: .top) { Rectangle().fill(EditorialPalette.ink).frame(height: 1) }
    }

    @ViewBuilder
    private var conversationContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 18)
            if let originalGoal {
                HStack {
                    Spacer(minLength: 44)
                    Text(originalGoal)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(EditorialPalette.cobalt)
                        .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
                }
            }
            if let clarificationQuestion {
                AssistantPanel {
                    VStack(alignment: .leading, spacing: 8) {
                        if let resultSource { PlannerSourceLabel(source: resultSource) }
                        Text(clarificationQuestion)
                        .font(.title3.weight(.black))
                        .foregroundStyle(EditorialPalette.ink)
                    }
                }
            }
            if isGenerating {
                AssistantPanel {
                    HStack(spacing: 12) {
                        EditorialLoader(stage: generationStage)
                        Text(generationMessages[generationStage % generationMessages.count])
                            .foregroundStyle(EditorialPalette.muted)
                    }
                }
            }
            if let draft {
                PlanPreviewView(plan: draft, source: resultSource, showAllBlocks: $showAllBlocks, onApply: applyDraft)
            }
            if let appliedPlanTitle {
                AssistantPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 9) {
                            ZStack {
                                Rectangle().fill(EditorialPalette.mint).frame(width: 28, height: 28)
                                EditorialCheckmark()
                                    .stroke(Color(hex: "#171714"), style: StrokeStyle(lineWidth: 2.4, lineCap: .square))
                                    .frame(width: 17, height: 17)
                            }
                            Text("ai.applied").font(.headline.weight(.black))
                        }
                        Text(appliedPlanTitle).font(.subheadline).foregroundStyle(EditorialPalette.muted)
                        HStack(spacing: 10) {
                            Button("ai.view_today", action: openToday)
                                .buttonStyle(EditorialPrimaryButtonStyle(fill: EditorialPalette.acid, foreground: Color(hex: "#171714")))
                            if model.canUndoAIPlan {
                                Button("action.undo") {
                                    model.undoLastAIPlan()
                                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                                        self.appliedPlanTitle = nil
                                    }
                                }
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(EditorialPalette.ink)
                                .frame(minWidth: 72, minHeight: 48)
                                .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
                            }
                        }
                    }
                }
            }
        }
    }

    private var challengeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("challenge.starter")
                    .font(.headline.weight(.black))
                    .foregroundStyle(EditorialPalette.ink)
                Spacer()
                Text("challenge.issue")
                    .font(.caption2.monospaced().weight(.black))
                    .foregroundStyle(EditorialPalette.coralText)
            }
            Text("challenge.no_fake_stats")
                .font(.caption2)
                .foregroundStyle(EditorialPalette.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(StarterChallengeCatalog.all.enumerated()), id: \.element.id) { index, challenge in
                        ChallengeCard(index: index, challenge: challenge) {
                            start(challenge: challenge)
                        }
                    }
                }
                .padding(.bottom, 6)
                .padding(.trailing, 5)
            }
        }
        .padding(.top, 12)
    }

    private func start(challenge: CommunityChallengeDefinition) {
        input = localized(challenge.promptKey)
        submit()
    }

    private func submit() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isGenerating else { return }
        let goal = originalGoal ?? trimmed
        let answer = originalGoal == nil || trimmed == originalGoal ? nil : trimmed
        lastSubmission = trimmed
        errorMessage = nil
        resultSource = nil
        if originalGoal == nil { originalGoal = trimmed }
        input = ""
        clarificationQuestion = nil
        draft = nil
        isGenerating = true
        generationStage = 0

        Task {
            let stageTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(650))
                    guard !Task.isCancelled else { return }
                    generationStage = (generationStage + 1) % generationMessages.count
                }
            }
            defer { stageTask.cancel() }
            do {
                let request = model.plannerRequest(goal: goal, clarificationAnswer: answer)
                let result = try await model.aiPlanner.generateResult(request)
                let turn = result.turn
                resultSource = result.source
                isGenerating = false
                switch turn.kind {
                case .clarification:
                    clarificationQuestion = turn.question
                    composerFocused = true
                case .plan:
                    draft = turn.plan
                }
            } catch {
                isGenerating = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func applyDraft() {
        guard let draft else { return }
        if let key = model.applyGeneratedPlan(draft) {
            errorMessage = localized(key)
            return
        }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            appliedPlanTitle = draft.title
            self.draft = nil
        }
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct ComposerField: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    let isBusy: Bool
    let submit: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("landing.placeholder", text: $text, axis: .vertical)
                .focused(focused)
                .lineLimit(1...5)
                .submitLabel(.send)
                .onSubmit(submit)
                .padding(.leading, 5)
                .padding(.vertical, 6)
            Button(action: submit) {
                ZStack {
                    Rectangle()
                        .fill(canSubmit ? EditorialPalette.acid : EditorialPalette.rule)
                        .frame(width: 42, height: 42)
                    if isBusy {
                        Text("···")
                            .font(.headline.monospaced().weight(.black))
                            .foregroundStyle(EditorialPalette.ink)
                    } else {
                        EditorialArrowGlyph(color: Color(hex: "#171714"))
                    }
                }
            }
            .disabled(!canSubmit || isBusy)
            .accessibilityLabel("landing.send")
        }
        .padding(10)
        .background(EditorialPalette.sheet)
        .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
        .background(EditorialPalette.ink.offset(x: 5, y: 5))
    }

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct AssistantPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            DayVaultMark(size: 28)
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(EditorialPalette.sheet)
        .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
    }
}

private struct EditorialLoader: View {
    let stage: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Rectangle()
                    .fill(index == stage % 3 ? EditorialPalette.coral : EditorialPalette.rule)
                    .frame(width: 8, height: 22 - CGFloat(index * 4))
            }
        }
        .frame(width: 32, height: 28)
        .accessibilityHidden(true)
    }
}

private struct ChallengeCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let index: Int
    let challenge: CommunityChallengeDefinition
    let join: () -> Void

    private var signal: Color {
        [EditorialPalette.cobalt, EditorialPalette.coral, EditorialPalette.mint][index % 3]
    }

    private var signalText: Color {
        [EditorialPalette.cobalt, EditorialPalette.coralText, EditorialPalette.mintText][index % 3]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(format: "%02d", index + 1))
                    .font(.title2.monospaced().weight(.black))
                    .foregroundStyle(signalText)
                Spacer()
                ChallengeMotif(index: index, color: signal)
            }
            Text(LocalizedStringKey(challenge.titleKey))
                .font(.headline.weight(.black))
                .foregroundStyle(EditorialPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(LocalizedStringKey(challenge.subtitleKey))
                .font(.caption)
                .foregroundStyle(EditorialPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("challenge.join", action: join)
                .font(.caption.weight(.black))
                .foregroundStyle(EditorialPalette.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(EditorialPalette.acid)
                .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
        }
        .padding(14)
        .frame(width: dynamicTypeSize.isAccessibilitySize ? 248 : 204, alignment: .leading)
        .frame(minHeight: 178, alignment: .leading)
        .background(EditorialPalette.sheet)
        .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
        .background(EditorialPalette.ink.offset(x: 4, y: 4))
    }
}

private struct ChallengeMotif: View {
    let index: Int
    let color: Color

    var body: some View {
        Canvas { context, size in
            let unit = size.width / 4
            for row in 0..<3 {
                for column in 0..<4 where (row + column + index).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(column) * unit, y: CGFloat(row) * unit, width: unit - 2, height: unit - 2)
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: 36, height: 27)
        .accessibilityHidden(true)
    }
}

private struct PlanPreviewView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let plan: GeneratedProjectPlan
    let source: AIPlannerSource?
    @Binding var showAllBlocks: Bool
    let onApply: () -> Void

    private var visibleBlocks: ArraySlice<GeneratedPlanBlock> {
        showAllBlocks ? plan.initialBlocks[...] : plan.initialBlocks.prefix(6)
    }

    var body: some View {
        AssistantPanel {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    if let source { PlannerSourceLabel(source: source) }
                    Text(plan.title)
                        .font(.title2.weight(.black))
                        .foregroundStyle(EditorialPalette.ink)
                    Text(plan.clarifiedGoal)
                        .font(.subheadline)
                        .foregroundStyle(EditorialPalette.muted)
                    HStack(spacing: 6) {
                        Text("ai.deadline").fontWeight(.black)
                        Text(plan.deadline.formatted(date: .abbreviated, time: .omitted))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(EditorialPalette.cobalt)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("ai.plan.roadmap")
                        .font(.headline.weight(.black))
                        .padding(.bottom, 10)
                    ForEach(Array(plan.phases.enumerated()), id: \.element.id) { index, phase in
                        HStack(alignment: .top, spacing: 10) {
                            Text(String(format: "%02d", index + 1))
                                .font(.caption.monospaced().weight(.black))
                                .foregroundStyle(EditorialPalette.coralText)
                                .frame(width: 26, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(phase.title).font(.subheadline.weight(.black))
                                Text(phase.summary).font(.caption).foregroundStyle(EditorialPalette.muted)
                            }
                        }
                        .padding(.vertical, 9)
                        .overlay(alignment: .bottom) { Rectangle().fill(EditorialPalette.rule).frame(height: 1) }
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("ai.plan.next_steps")
                        .font(.headline.weight(.black))
                        .padding(.bottom, 10)
                    ForEach(visibleBlocks) { block in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(block.start, format: .dateTime.weekday(.abbreviated))
                                Text(block.start, style: .time)
                            }
                            .font(.caption2.monospacedDigit().weight(.black))
                            .foregroundStyle(EditorialPalette.cobalt)
                            .frame(width: 54, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(block.title).font(.subheadline.weight(.bold)).lineLimit(2)
                                Text(String(format: NSLocalizedString("agenda.minutes", comment: ""), block.durationMinutes))
                                    .font(.caption2).foregroundStyle(EditorialPalette.muted)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) { Rectangle().fill(EditorialPalette.rule).frame(height: 1) }
                    }
                    if plan.initialBlocks.count > 6 {
                        Button(showAllBlocks ? "ai.plan.show_less" : "ai.plan.show_all") {
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                                showAllBlocks.toggle()
                            }
                        }
                        .font(.caption.weight(.black))
                        .foregroundStyle(EditorialPalette.cobalt)
                        .padding(.top, 10)
                    }
                }

                if !plan.assumptions.isEmpty || !plan.warnings.isEmpty {
                    DisclosureGroup("ai.plan.assumptions") {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(plan.assumptions, id: \.self) { Text("• \($0)") }
                            ForEach(plan.warnings, id: \.self) {
                                Text("! \($0)").foregroundStyle(EditorialPalette.coralText)
                            }
                        }
                        .font(.caption)
                        .padding(.top, 6)
                    }
                    .tint(EditorialPalette.ink)
                }

                Button("ai.use_plan", action: onApply)
                    .buttonStyle(EditorialPrimaryButtonStyle(fill: EditorialPalette.acid, foreground: Color(hex: "#171714")))
            }
        }
    }
}

private struct PlannerSourceLabel: View {
    let source: AIPlannerSource

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(source.label)
                .font(.caption2.weight(.black))
                .foregroundStyle(EditorialPalette.coralText)
                .accessibilityIdentifier("planner-result-source")
            if !source.detail.isEmpty {
                Text(source.detail)
                    .font(.caption2)
                    .foregroundStyle(EditorialPalette.muted)
                    .accessibilityIdentifier("planner-result-version")
            }
        }
    }
}
