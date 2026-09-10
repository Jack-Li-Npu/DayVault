import DayVaultCore
import SwiftUI
import UIKit

struct PersonalAchievementsView: View {
    @Environment(AppModel.self) private var model
    @State private var selected: PersonalAchievementDefinition?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("只属于这段旅程。")
                .font(.title2.weight(.black)).foregroundStyle(.white)
            Text("依据个人记录 · 不参与公共成就数量或全球排名")
                .font(.caption).foregroundStyle(.white.opacity(0.65))
            if model.personalAchievements.isEmpty {
                Text("在目标中开启 AI 陪伴后，搭档会设计最多两项明确成就和一个隐藏彩蛋。尚未连接 AI 时，不会生成虚假的专属成就。")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.75))
                    .padding(18).background(EditorialPalette.vaultSheet)
            }
            ForEach(model.visiblePersonalAchievements.filter { $0.archivedAt == nil || model.personalState($0)?.unlockedAt != nil }) { definition in
                let state = model.personalState(definition)
                let concealed = definition.isHidden && state?.unlockedAt == nil
                Button { selected = definition } label: {
                    HStack(spacing: 16) {
                        PersonalBadgeView(style: concealed ? "concealed" : definition.badgeStyleID)
                            .frame(width: 66, height: 66)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(concealed ? "未署名的成就" : definition.title).font(.headline.weight(.bold))
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
                                Text(ruleDescription(definition)).font(.caption).foregroundStyle(.white.opacity(0.7))
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
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PersonalBadgeView(style: concealed ? "concealed" : definition.badgeStyleID).frame(width: 110, height: 110)
                    Text(concealed ? "未署名的成就" : definition.title).font(.largeTitle.weight(.black))
                    if concealed {
                        Text(signalName(state?.signal ?? .dormant)).foregroundStyle(EditorialPalette.acid)
                        if state?.signal == .resonant { Text(concealedClue(definition)) }
                        else { Text("先留一点悬念。继续记录就好。").foregroundStyle(.white.opacity(0.65)) }
                    } else {
                        Text(definition.detail)
                        Text(ruleDescription(definition)).font(.subheadline).foregroundStyle(EditorialPalette.acid)
                        let result = PersonalAchievementEngine.evaluate(definition, logs: model.logs)
                        Text("当前记录：\(result.metricValue) / \(definition.rule?.target ?? 0)")
                            .font(.caption.monospacedDigit())
                    }
                    if let date = state?.unlockedAt {
                        Text("获得于 \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption)
                        Button("看看我们的配合") { showsDuet = true }
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
                        Button("停用这项成就") {
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
        VStack(alignment: .leading, spacing: 14) {
            Text("DAYVAULT / 我的旅程").font(.caption.monospaced().weight(.bold))
            HStack {
                DayVaultAvatar(outfit: model.avatarOutfit, pose: .proud, animated: false).frame(width: 180, height: 220)
                PersonalBadgeView(style: definition.badgeStyleID).frame(width: 88, height: 88)
            }
            Text(definition.title).font(.title.weight(.black))
            Text(ruleDescription(definition)).font(.subheadline)
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
                    Button("分享这张卡") {
                        let renderer = ImageRenderer(content: card)
                        renderer.scale = 3
                        if let rendered = renderer.uiImage { image = SharedJourneyImage(image: rendered) }
                    }.buttonStyle(EditorialPrimaryButtonStyle(fill: EditorialPalette.acid, foreground: .black))
                }.padding(16)
            }.background(EditorialPalette.paper)
            .navigationTitle("分享前看一眼").navigationBarTitleDisplayMode(.inline)
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
    switch signal { case .dormant: "尚未苏醒"; case .faint: "微弱信号"; case .resonant: "正在共鸣" }
}

private func concealedClue(_ definition: PersonalAchievementDefinition) -> String {
    // Model-authored clues may contain exact thresholds; only local copy is safe before unlock.
    switch definition.rule?.kind {
    case .completionCount: "那些做完的小事，正在留下轮廓。"
    case .activeDays: "散落在日历里的脚印，开始连起来了。"
    case .completedCycles: "熟悉的节奏里，藏着新的回响。"
    case nil: "轮廓渐渐清晰。继续按自己的节奏记录。"
    }
}

private func ruleDescription(_ definition: PersonalAchievementDefinition) -> String {
    guard let rule = definition.rule else { return "等待完整定义同步" }
    switch rule.kind {
    case .completionCount: return "这个目标累计完成 \(rule.target) 次"
    case .activeDays: return "在 \(rule.target) 个不同日期留下完成记录"
    case .completedCycles: return "每 \(rule.cycleLengthDays) 天行动 \(rule.requiredDaysPerCycle) 天，累计完成 \(rule.target) 个周期"
    }
}
