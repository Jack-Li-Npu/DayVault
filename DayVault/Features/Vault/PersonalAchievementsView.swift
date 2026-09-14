import DayVaultCore
import SwiftUI
import UIKit

struct PersonalAchievementsView: View {
    @Environment(AppModel.self) private var model
    @State private var selected: PersonalAchievementDefinition?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("个人成就")
                .accessibilityIdentifier("personal-achievements-heading")
                .font(.title2.weight(.black)).foregroundStyle(.white)
            Text("保留已有成就，按原条件继续积累。")
                .font(.caption).foregroundStyle(.white.opacity(0.65))
            if model.personalAchievements.isEmpty {
                Text("暂无个人成就。可在公共成就册中查看可收集的成就。")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.75))
                    .padding(18).background(EditorialPalette.vaultSheet)
            }
            ForEach(model.visiblePersonalAchievements.filter { $0.archivedAt == nil || model.personalState($0)?.unlockedAt != nil }) { definition in
                let state = model.personalState(definition)
                let concealed = definition.isHidden && state?.unlockedAt == nil
                let copy = PersonalAchievementCopy(definition: definition, isUnlocked: state?.unlockedAt != nil)
                Button { selected = definition } label: {
                    HStack(spacing: 16) {
                        PersonalBadgeView(style: concealed ? "concealed" : definition.badgeStyleID)
                            .frame(width: 66, height: 66)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(copy.title).font(.headline.weight(.bold))
                            Text(model.goals.first { $0.id == definition.goalID }?.title ?? "个人目标")
                                .font(.caption).foregroundStyle(.white.opacity(0.6))
                            if !model.activePersonalDefinitionKeys.contains(definition.definitionKey) {
                                Text("历史版本 · 已获荣誉保留").font(.caption2)
                            }
                            if concealed {
                                Text(signalName(state?.signal ?? .dormant)).font(.caption).foregroundStyle(EditorialPalette.acid)
                            } else if state?.unlockedAt != nil {
                                Text("已获得").font(.caption).foregroundStyle(EditorialPalette.acid)
                            } else {
                                ProgressView(value: state?.progress ?? 0).tint(EditorialPalette.acid)
                                Text(copy.condition).font(.caption).foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16).background(EditorialPalette.vaultSheet)
                    .overlay { Rectangle().stroke(Color.white.opacity(0.2)) }
                }.buttonStyle(.plain).foregroundStyle(.white)
            }
        }
        .sheet(item: $selected) { PersonalAchievementDetail(definition: $0) }
    }
}

struct PersonalBadgeView: View {
    let style: String
    var body: some View {
        ZStack {
            Canvas { context, size in
                let inset: CGFloat = 4
                let rect = CGRect(x: inset, y: inset, width: size.width - 2 * inset, height: size.height - 2 * inset)
                var shape = Path()
                shape.move(to: CGPoint(x: rect.midX, y: rect.minY))
                shape.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.25))
                shape.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.25))
                shape.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
                shape.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.25))
                shape.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.25))
                shape.closeSubpath()
                context.fill(shape, with: .color(style == "concealed" ? Color.white.opacity(0.08) : EditorialPalette.acid))
                context.stroke(shape, with: .color(Color.white.opacity(0.4)), lineWidth: 1)
                if style != "concealed" {
                    var fold = Path()
                    fold.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.25))
                    fold.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
                    fold.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.25))
                    context.stroke(fold, with: .color(.black.opacity(0.2)), lineWidth: 1)
                }
            }
            Text(glyph).font(.system(size: 29, weight: .black, design: .monospaced))
                .foregroundStyle(style == "concealed" ? .white.opacity(0.5) : Color.black)
        }.accessibilityHidden(true)
    }
    private var glyph: String {
        switch style { case "crest": "V"; case "orbit": "◎"; case "steps": "↗"; case "spark": "✦"; case "ribbon": "≋"; default: "?" }
    }
}

private struct PersonalAchievementDetail: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let definition: PersonalAchievementDefinition
    @State private var showsDuet = false
    @State private var showsShare = false
    @State private var error: String?
    private var state: AchievementState? { model.personalState(definition) }
    private var concealed: Bool { definition.isHidden && state?.unlockedAt == nil }
    private var copy: PersonalAchievementCopy {
        PersonalAchievementCopy(definition: definition, isUnlocked: state?.unlockedAt != nil)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PersonalBadgeView(style: concealed ? "concealed" : definition.badgeStyleID).frame(width: 110, height: 110)
                    Text(copy.title).font(.largeTitle.weight(.black))
                    if concealed {
                        Text(signalName(state?.signal ?? .dormant)).foregroundStyle(EditorialPalette.acid)
                        if state?.signal == .resonant { Text(concealedClue(definition)) }
                        else { Text("线索尚未解锁。").foregroundStyle(.white.opacity(0.65)) }
                    } else {
                        Text(copy.condition).font(.subheadline).foregroundStyle(EditorialPalette.acid)
                        let result = PersonalAchievementEngine.evaluate(definition, logs: model.logs)
                        Text(copy.progressLabel(value: result.metricValue))
                            .font(.caption.monospacedDigit())
                        DisclosureGroup("历史原始文案") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(definition.title).font(.headline)
                                Text(definition.detail)
                                Text("保留生成时的文案。成就条件以当前显示的规则为准，名称调整不影响解锁记录。")
                                    .font(.caption).foregroundStyle(.white.opacity(0.6))
                            }.padding(.top, 8)
                        }.font(.caption)
                    }
                    if let date = state?.unlockedAt {
                        Text("获得于 \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption)
                        Button("回顾成长演出") { showsDuet = true }
                            .buttonStyle(AvatarOutlineButtonStyle())
                        Button("预览分享卡") { showsShare = true }
                            .buttonStyle(EditorialPrimaryButtonStyle(fill: EditorialPalette.acid, foreground: .black))
                        if let evidence = model.personalEvidence.first(where: { $0.definitionKey == definition.definitionKey }) {
                            DisclosureGroup("解锁依据") {
                                let versions = JourneyJSON.decode([String: String].self, from: evidence.sourceVersionsJSON) ?? [:]
                                let current = model.currentSourceVersions()
                                ForEach(evidence.occurrenceKeys, id: \.self) { key in
                                    if (versions[key] == nil || versions[key] == current[key]), let log = model.logs.first(where: { $0.occurrenceKey == key && $0.status == .completed && $0.goalID == definition.goalID }) {
                                        Text("\((log.completedAt ?? log.originalStart).formatted(date: .abbreviated, time: .omitted)) · 已记录完成")
                                    } else { Text("原记录已修改或移除；已获荣誉仍保留。") }
                                }
                            }.font(.caption)
                        }
                    } else {
                        Button("停用成就") {
                            do { try model.archivePersonalAchievement(definition); dismiss() }
                            catch { self.error = error.localizedDescription }
                        }.frame(minHeight: 44)
                    }
                    if let error { Text(error) }
                }.padding(24)
            }
            .foregroundStyle(.white).background(EditorialPalette.vault)
            .preferredColorScheme(.dark)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("返回") { dismiss() } } }
            .sheet(isPresented: $showsDuet) {
                DuetCelebrationView(outfit: model.avatarOutfit, companionDays: model.companionDayCount(for: definition.goalID)) { showsDuet = false }
            }
            .sheet(isPresented: $showsShare) { PersonalSharePreview(definition: definition) }
        }
    }
}

private struct PersonalSharePreview: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let definition: PersonalAchievementDefinition
    @State private var selectedMemoryID: UUID?
    @State private var image: SharedJourneyImage?
    private var memory: CompanionMemory? { model.companionMemories.first { $0.id == selectedMemoryID } }
    private var dates: [Date] {
        guard let rule = definition.rule, rule.isValid else { return [] }
        let now = Date()
        let latest = Dictionary(model.logs.map { ($0.occurrenceKey, $0) }, uniquingKeysWith: { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt ? lhs : rhs }
            return lhs.id.uuidString < rhs.id.uuidString ? lhs : rhs
        })
        return latest.values.compactMap { log -> Date? in
            guard log.goalID == definition.goalID, log.status == .completed,
                  !log.occurrenceKey.isEmpty, let date = log.completedAt,
                  date.timeIntervalSince1970.isFinite, date >= rule.startsAt, date <= now,
                  rule.endsAt.map({ date <= $0 }) ?? true,
                  (log.overrideStart ?? log.originalStart) <= now else { return nil }
            return date
        }.sorted()
    }
    private var card: some View {
        let copy = PersonalAchievementCopy(definition: definition, isUnlocked: model.personalState(definition)?.unlockedAt != nil)
        return VStack(alignment: .leading, spacing: 14) {
            Text("DAYVAULT / 成就档案").font(.caption.monospaced().weight(.bold))
            HStack {
                DayVaultAvatar(outfit: model.avatarOutfit, pose: .proud, animated: false).frame(width: 180, height: 220)
                PersonalBadgeView(style: definition.badgeStyleID).frame(width: 88, height: 88)
            }
            Text(copy.title).font(.title.weight(.black))
            Text(copy.condition).font(.subheadline)
            if let first = dates.first, let last = dates.last {
                Text("\(first.formatted(date: .abbreviated, time: .omitted)) — \(last.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
            }
            if let memory { Text(memory.text).font(.subheadline).fixedSize(horizontal: false, vertical: true) }
            Text("依据个人记录 · 不是全球排名或外部认证").font(.caption2).foregroundStyle(.white.opacity(0.6))
        }
        .padding(24).frame(width: 350, alignment: .leading)
        .foregroundStyle(.white).background(EditorialPalette.vaultSheet)
        .environment(\.colorScheme, .dark)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    card
                    Picker("附上一段记忆", selection: $selectedMemoryID) {
                        Text("不附私人内容").tag(UUID?.none)
                        ForEach(model.companionMemories.filter { $0.goalID == definition.goalID && $0.isConfirmed }) { memory in
                            Text(memory.text).tag(Optional(memory.id))
                        }
                    }
                    Button("分享卡片") {
                        let renderer = ImageRenderer(content: card)
                        renderer.scale = 3
                        if let rendered = renderer.uiImage { image = SharedJourneyImage(image: rendered) }
                    }.buttonStyle(EditorialPrimaryButtonStyle(fill: EditorialPalette.acid, foreground: .black))
                }.padding(16)
            }.background(EditorialPalette.paper)
            .navigationTitle("分享预览").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("返回") { dismiss() } } }
            .sheet(item: $image) { JourneyActivitySheet(image: $0.image) }
        }
    }
}

private struct SharedJourneyImage: Identifiable { let id = UUID(); let image: UIImage }
private struct JourneyActivitySheet: UIViewControllerRepresentable {
    let image: UIImage
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [image], applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private func signalName(_ signal: HiddenSignal) -> String {
    NSLocalizedString("signal.\(signal.rawValue)", comment: "")
}

private func concealedClue(_ definition: PersonalAchievementDefinition) -> String {
    // Model-authored clues may contain exact thresholds; only local copy is safe before unlock.
    switch definition.rule?.kind {
    case .completionCount: "奖励藏在平常的完成记录里。"
    case .activeDays: "有些奖励，要分几天寻找。"
    case .completedCycles: "按约定的安排完成，再回来看看。"
    case nil: "继续记录，线索会逐步出现。"
    }
}

/// Presentation only: persisted AI text and frozen eligibility rules stay untouched.
struct PersonalAchievementCopy {
    let title: String
    let condition: String
    private let target: Int?
    private let unit: String

    init(definition: PersonalAchievementDefinition, isUnlocked: Bool) {
        guard !definition.isHidden || isUnlocked else {
            title = "隐藏成就"
            condition = "解锁后显示条件。"
            target = nil
            unit = ""
            return
        }
        guard let rule = definition.rule, rule.isValid else {
            title = "个人成就"
            condition = "成就条件暂不可用。"
            target = nil
            unit = ""
            return
        }
        target = rule.target
        switch rule.kind {
        case .completionCount:
            title = rule.target == 1 ? "首次完成" : "完成 \(rule.target) 次"
            condition = "累计完成 \(rule.target) 项关联事项。"
            unit = "次"
        case .activeDays:
            title = rule.target == 1 ? "首次完成" : "累计记录 \(rule.target) 天"
            condition = rule.target == 1
                ? "完成目标内的一项任务。"
                : "累计 \(rule.target) 天完成过目标内的事项，无需连续。"
            unit = "天"
        case .completedCycles:
            title = "达标 \(rule.target) 个周期"
            condition = "每 \(rule.cycleLengthDays) 天中，至少 \(rule.requiredDaysPerCycle) 天完成过目标内的事项；累计达标 \(rule.target) 个周期。"
            unit = "个周期"
        }
    }

    func progressLabel(value: Int) -> String {
        guard let target else { return "" }
        return "\(value) / \(target) \(unit)"
    }
}
