import DayVaultCore
import SwiftUI

struct CompanionSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let goalID: UUID?
    @State private var input = ""
    @State private var error: String?
    @State private var showsConsent = false
    @State private var showsMemories = false
    @State private var showsDuet = false
    @State private var adjustment: PlanAdjustmentRecord?
    private var goal: PersonalGoal? { model.goals.first { $0.id == goalID } }

    var body: some View {
        if let goal {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            OrigamiCompanion(days: model.companionDayCount(for: goal.id))
                                .frame(width: 72, height: 72)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(goal.title).font(.title3.weight(.bold))
                                Text("一起记录了 \(model.companionDayCount(for: goal.id)) 天")
                                    .font(.caption).foregroundStyle(EditorialPalette.muted)
                            }
                        }
                        if goal.aiEnabledAt == nil {
                            Text("开启 AI 后，可以聊聊这个目标，设计个人成就，或查看改期建议。不开启也能照常记录。")
                                .font(.subheadline)
                            Button("开启这个目标的 AI 陪伴") { showsConsent = true }
                                .buttonStyle(EditorialPrimaryButtonStyle(fill: EditorialPalette.acid, foreground: Color(hex: "#171714")))
                                .accessibilityIdentifier("companion-enable")
                        } else {
                            conversation(goal)
                        }
                        if let error {
                            Text(error).font(.subheadline).foregroundStyle(EditorialPalette.coralText)
                                .accessibilityIdentifier("companion-error")
                        }
                    }.padding(20)
                }
                .background(EditorialPalette.paper).foregroundStyle(EditorialPalette.ink)
                .navigationTitle("搭档").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Button("查看与管理记忆") { showsMemories = true }
                            Button("看看我们的配合") { showsDuet = true }
                            Button("清除这段对话", role: .destructive) {
                                perform { try model.clearConversation(goalID: goal.id) }
                            }
                            if goal.aiEnabledAt != nil {
                                Button("暂停 AI 陪伴") { perform { try model.disableGoalAI(goal.id) } }
                            }
                        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                        .accessibilityIdentifier("companion-options")
                    }
                    ToolbarItem(placement: .topBarTrailing) { Button("返回") { dismiss() }.accessibilityIdentifier("companion-close") }
                }
                .sheet(isPresented: $showsConsent) { consent(goal) }
                .sheet(isPresented: $showsMemories) { CompanionMemoryView(goalID: goal.id) }
                .sheet(isPresented: $showsDuet) {
                    DuetCelebrationView(outfit: model.avatarOutfit, companionDays: model.companionDayCount(for: goal.id), isPreview: true) { showsDuet = false }
                }
                .sheet(item: $adjustment) { AdjustmentPreviewView(record: $0) }
            }
        } else { GoalManagerView() }
    }

    @ViewBuilder private func conversation(_ goal: PersonalGoal) -> some View {
        if goal.achievementGenerationState != "complete" {
            Button("重试设计个人成就") {
                Task { do { try await model.generatePersonalAchievements(goal.id) } catch { self.error = error.localizedDescription } }
            }.disabled(model.journeyBusy).frame(minHeight: 44)
        }
        let messages = model.companionMessages.filter { $0.goalID == goal.id && ["user", "assistant"].contains($0.role) && !$0.text.isEmpty }
        if messages.isEmpty {
            Text("今天做得怎么样？有想记下来的事，可以在这里说。")
                .foregroundStyle(EditorialPalette.muted)
        }
        ForEach(messages) { message in
            VStack(alignment: .leading, spacing: 8) {
                Text(message.role == "user" ? "我" : "搭档").font(.caption.weight(.bold))
                Text(message.text).textSelection(.enabled)
                if !message.sourceOccurrenceKeys.isEmpty {
                    DisclosureGroup("查看依据") {
                        ForEach(message.sourceOccurrenceKeys, id: \.self) { key in
                            Text(model.journeySourceDescription(key)).font(.caption)
                        }
                    }.font(.caption)
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(message.role == "user" ? EditorialPalette.acid.opacity(0.2) : EditorialPalette.sheet)
        }
        HStack(alignment: .bottom) {
            TextField("聊聊这个目标…", text: $input, axis: .vertical)
                .lineLimit(1...4).accessibilityIdentifier("companion-input")
            Button("发送") {
                let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
                input = ""; error = nil
                Task { do { try await model.sendCompanionMessage(goalID: goal.id, text: text) } catch { self.error = error.localizedDescription; input = text } }
            }.disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.journeyBusy)
                .frame(minWidth: 44, minHeight: 44)
        }.padding(14).background(EditorialPalette.sheet)
        if model.journeyBusy { ProgressView("正在处理，可以先返回记录。") }
        Button("看看未来七天怎么调整") {
            Task {
                do {
                    let id = try await model.proposeAdjustment(goalID: goal.id, message: input.isEmpty ? "在不减少任务量的前提下，检查未来七天是否需要调整。" : input)
                    adjustment = model.adjustmentRecords.first { $0.id == id }
                } catch { self.error = error.localizedDescription }
            }
        }.disabled(model.journeyBusy).frame(minHeight: 44)
        ForEach(model.adjustmentRecords.filter { $0.goalID == goal.id && $0.appliedAt != nil }.sorted { $0.createdAt > $1.createdAt }.prefix(3)) { record in
            Button(record.revertedAt == nil ? "查看已执行的调整" : "查看已撤销的调整") { adjustment = record }
                .frame(minHeight: 44)
        }
    }

    private func consent(_ goal: PersonalGoal) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("开启前，看看会发送什么") .font(.title2.weight(.bold))
                    Text("发送：目标名称、已关联完成记录摘要、你主动说的话和确认过的记忆。调整安排时额外发送匿名忙闲区间。不会发送其他目标、全部日记或日历标题。")
                    Text("连接：\(providerDescription)").font(.caption).foregroundStyle(EditorialPalette.muted)
                    Text("首次开启后，为这个目标设计最多两项明确成就和一项隐藏彩蛋。不会额外安排任务；任何日程修改都需要你确认。")
                    Button("同意并开启") {
                        showsConsent = false
                        Task { do { try await model.enableGoalAI(goal.id) } catch { self.error = error.localizedDescription } }
                    }.buttonStyle(EditorialPrimaryButtonStyle(fill: EditorialPalette.acid, foreground: Color(hex: "#171714")))
                        .accessibilityIdentifier("companion-consent-confirm")
                    Text("可以随时暂停、管理记忆。暂未连接时，记录和已获得的成就照常保留。")
                        .font(.caption).foregroundStyle(EditorialPalette.muted)
                }.padding(24)
            }.background(EditorialPalette.paper)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("暂不开启") { showsConsent = false } } }
        }
    }

    private var providerDescription: String {
        let endpoint = ProcessInfo.processInfo.environment["DAYVAULT_AI_ENDPOINT"] ?? UserDefaults.standard.string(forKey: "aiPlannerEndpoint")
        guard let endpoint, let host = URL(string: endpoint)?.host else { return "尚未配置 AI 服务" }
        if ["localhost", "127.0.0.1"].contains(host) { return "本地测试代理（使用前请向配置者确认实际模型服务商）" }
        return "\(host) 服务代理；上游服务由该代理配置"
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { self.error = error.localizedDescription }
    }
}

private struct CompanionMemoryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let goalID: UUID
    @State private var error: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("确认后，这些内容才会用于以后的建议。")
                    ForEach(model.companionMemories.filter { $0.goalID == goalID }) { memory in
                        MemoryEditor(memory: memory) { action in
                            do { try action() } catch { self.error = error.localizedDescription }
                        }
                    }
                    if let error { Text(error).foregroundStyle(.red) }
                }.padding(20)
            }.background(EditorialPalette.paper)
            .navigationTitle("我们试过的方法").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("返回") { dismiss() } } }
        }
    }
}

private struct MemoryEditor: View {
    @Environment(AppModel.self) private var model
    let memory: CompanionMemory
    let perform: (() throws -> Void) -> Void
    @State private var text = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(memory.isConfirmed ? "已确认" : "要记住这件事吗？").font(.caption.weight(.bold))
            TextField("这条经验", text: $text, axis: .vertical)
            if !memory.sourceOccurrenceKeys.isEmpty {
                DisclosureGroup("查看依据") {
                    ForEach(memory.sourceOccurrenceKeys, id: \.self) { key in
                        Text(model.journeySourceDescription(key)).font(.caption)
                    }
                }.font(.caption)
            }
            HStack {
                Button(memory.isConfirmed ? "保存修改" : "确认记住") { perform { try model.confirmMemory(memory, text: text) } }
                Spacer()
                Button("删除", role: .destructive) { perform { try model.deleteMemory(memory) } }
            }.frame(minHeight: 44)
        }.padding(16).background(EditorialPalette.sheet)
            .onAppear { text = memory.text }
    }
}

struct AdjustmentPreviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let record: PlanAdjustmentRecord
    @State private var error: String?
    @State private var applying = false
    private var envelope: AdjustmentEnvelope? { JourneyJSON.decode(AdjustmentEnvelope.self, from: record.afterJSON) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(record.reason).font(.headline)
                    Text("只移动这几项安排；时长、任务量和目标期限不变。")
                        .font(.caption).foregroundStyle(EditorialPalette.muted)
                    if let envelope {
                        ForEach(envelope.suggestion.changes, id: \.occurrenceID) { change in
                            if let old = envelope.request.allowedOccurrences.first(where: { $0.id == change.occurrenceID }) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(title(change.occurrenceID)).font(.headline)
                                    Text("\(date(old.start, timed: old.isTimed)) → \(date(change.newStart, timed: old.isTimed))")
                                        .font(.subheadline)
                                }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(EditorialPalette.sheet)
                            }
                        }
                    }
                    if record.revertedAt != nil { Text("已撤销，原安排已恢复。") }
                    else {
                        Button(record.appliedAt == nil ? "确认这次调整" : "撤销这次调整") {
                            applying = true
                            Task {
                                do {
                                    if record.appliedAt == nil { try await model.applyAdjustment(record) }
                                    else { try await model.undoAdjustment(record) }
                                } catch { self.error = error.localizedDescription }
                                applying = false
                            }
                        }.buttonStyle(EditorialPrimaryButtonStyle(fill: EditorialPalette.acid, foreground: Color(hex: "#171714")))
                            .disabled(applying)
                    }
                    if let error { Text(error).foregroundStyle(EditorialPalette.coralText) }
                }.padding(20)
            }.background(EditorialPalette.paper)
            .navigationTitle(record.appliedAt == nil ? "先看看改哪里" : "调整记录").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("返回") { dismiss() } } }
        }
    }
    private func title(_ key: String) -> String {
        guard let id = key.split(separator: "|").first.flatMap({ UUID(uuidString: String($0)) }) else { return "事项" }
        return model.items.first { $0.id == id }?.title ?? "事项"
    }
    private func date(_ value: Date, timed: Bool) -> String {
        value.formatted(date: .abbreviated, time: timed ? .shortened : .omitted)
    }
}
