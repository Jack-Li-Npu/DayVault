import DayVaultCore
import SwiftUI

struct CompanionSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let goalID: UUID?
    @State private var error: String?
    @State private var confirmsClear = false
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
                                Text("历史共同记录：\(model.companionDayCount(for: goal.id)) 天")
                                    .font(.caption).foregroundStyle(EditorialPalette.muted)
                            }
                        }
                        Text("AI 功能已停用。这里保留旧版对话与回忆，不再生成回复或发送记录。")
                            .font(.subheadline).foregroundStyle(EditorialPalette.muted)
                        conversation(goal)
                        if let error {
                            Text(error).font(.subheadline).foregroundStyle(EditorialPalette.coralText)
                                .accessibilityIdentifier("companion-error")
                        }
                    }.padding(20)
                }
                .background(EditorialPalette.paper).foregroundStyle(EditorialPalette.ink)
                .navigationTitle("历史陪伴记录").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Button("历史回忆") { showsMemories = true }
                            Button("回顾成长演出") { showsDuet = true }
                            Button("清除对话", role: .destructive) { confirmsClear = true }
                        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                        .accessibilityIdentifier("companion-options")
                    }
                    ToolbarItem(placement: .topBarTrailing) { Button("返回") { dismiss() }.accessibilityIdentifier("companion-close") }
                }
                .confirmationDialog("清除这个目标的历史对话？", isPresented: $confirmsClear, titleVisibility: .visible) {
                    Button("清除对话", role: .destructive) {
                        perform { try model.clearConversation(goalID: goal.id) }
                    }
                    Button("取消", role: .cancel) { }
                } message: {
                    Text("此操作不可撤销。依赖这些对话的回忆引用也会撤下，日程与成就不受影响。")
                }
                .sheet(isPresented: $showsMemories) { CompanionMemoryView(goalID: goal.id) }
                .sheet(isPresented: $showsDuet) {
                    DuetCelebrationView(outfit: model.avatarOutfit, companionDays: model.companionDayCount(for: goal.id), isPreview: true) { showsDuet = false }
                }
                .sheet(item: $adjustment) { AdjustmentPreviewView(record: $0) }
            }
        } else { GoalManagerView() }
    }

    @ViewBuilder private func conversation(_ goal: PersonalGoal) -> some View {
        let messages = model.companionMessages.filter { $0.goalID == goal.id && ["user", "assistant"].contains($0.role) && !$0.text.isEmpty }
        if messages.isEmpty {
            Text("暂无历史对话。")
                .foregroundStyle(EditorialPalette.muted)
        }
        ForEach(messages) { message in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(message.role == "user" ? "我" : "AI 历史回复").font(.caption.weight(.bold))
                    Spacer()
                    Text(message.createdAt, format: .dateTime.year().month().day()).font(.caption2)
                }
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
        ForEach(model.adjustmentRecords.filter { $0.goalID == goal.id && $0.appliedAt != nil }.sorted { $0.createdAt > $1.createdAt }) { record in
            Button(record.revertedAt == nil ? "查看已执行的调整" : "查看已撤销的调整") { adjustment = record }
                .frame(minHeight: 44)
        }
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
                    Text("这里只管理旧版保存的回忆，不会用于生成建议。确认的内容仍可由你选择加入分享卡。")
                    if model.companionMemories.allSatisfy({ $0.goalID != goalID }) {
                        Text("暂无历史回忆。").foregroundStyle(EditorialPalette.muted)
                    }
                    ForEach(model.companionMemories.filter { $0.goalID == goalID }) { memory in
                        MemoryEditor(memory: memory) { action in
                            do { try action() } catch { self.error = error.localizedDescription }
                        }
                    }
                    if let error { Text(error).foregroundStyle(.red) }
                }.padding(20)
            }.background(EditorialPalette.paper)
            .navigationTitle("历史回忆").navigationBarTitleDisplayMode(.inline)
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
            Text(memory.isConfirmed ? "已确认" : "待确认记忆").font(.caption.weight(.bold))
            TextField("记忆内容", text: $text, axis: .vertical)
                .accessibilityIdentifier("archived-memory-input-\(memory.id.uuidString)")
            if !memory.sourceOccurrenceKeys.isEmpty {
                DisclosureGroup("查看依据") {
                    ForEach(memory.sourceOccurrenceKeys, id: \.self) { key in
                        Text(model.journeySourceDescription(key)).font(.caption)
                    }
                }.font(.caption)
            }
            HStack {
                Button(memory.isConfirmed ? "保存修改" : "确认保存") { perform { try model.confirmMemory(memory, text: text) } }
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
                    Text("以下为已保存的调整记录。撤销前会重新检查事项状态与时间冲突。")
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
                    else if record.appliedAt != nil {
                        Button("撤销调整") {
                            applying = true
                            Task {
                                do {
                                    try await model.undoAdjustment(record)
                                } catch { self.error = error.localizedDescription }
                                applying = false
                            }
                        }.buttonStyle(EditorialPrimaryButtonStyle(fill: EditorialPalette.acid, foreground: Color(hex: "#171714")))
                            .disabled(applying)
                    } else { Text("此历史提案未执行，可在日程中手动调整。") }
                    if let error { Text(error).foregroundStyle(EditorialPalette.coralText) }
                }.padding(20)
            }.background(EditorialPalette.paper)
            .navigationTitle("调整记录").navigationBarTitleDisplayMode(.inline)
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
