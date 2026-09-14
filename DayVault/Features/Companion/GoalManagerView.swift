import DayVaultCore
import SwiftUI

struct GoalManagerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var error: String?
    @State private var selectedDetail: PersonalGoal?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("创建目标")
                        .font(.title2.weight(.bold))
                    HStack {
                        TextField("输入目标名称", text: $title)
                            .accessibilityIdentifier("goal-title")
                        Button("建立") { create() }
                            .accessibilityIdentifier("goal-create")
                            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .padding(14).background(EditorialPalette.sheet)
                    .overlay { Rectangle().stroke(EditorialPalette.rule) }
                    if let error { Text(error).font(.caption).foregroundStyle(EditorialPalette.coralText) }
                    ForEach(model.goals) { goal in
                        HStack {
                            Button {
                                model.selectedGoalID = goal.id
                                dismiss()
                            } label: {
                                HStack {
                                    Text(goal.title).font(.headline)
                                    Spacer()
                                    if model.selectedGoalID == goal.id { Image(systemName: "checkmark") }
                                }.frame(minHeight: 48)
                            }
                            Button("详情") { selectedDetail = goal }
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .padding(14).background(EditorialPalette.sheet)
                    }
                    Text("目标用于归类事项，也可以不设目标，直接记录。")
                        .font(.caption).foregroundStyle(EditorialPalette.muted)
                }.padding(20)
            }
            .background(EditorialPalette.paper)
            .foregroundStyle(EditorialPalette.ink)
            .navigationTitle("我的目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("返回") { dismiss() }.accessibilityIdentifier("goals-close") } }
            .sheet(item: $selectedDetail) { GoalDetailView(goal: $0) }
        }
    }

    private func create() {
        do {
            let id = try model.createGoal(title: title)
            title = ""
            selectedDetail = model.goals.first { $0.id == id }
        } catch { self.error = error.localizedDescription }
    }
}

struct GoalDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let goal: PersonalGoal
    @State private var showsHistory = false
    @State private var showsArchive = false
    @State private var weeklyDays = 0
    @State private var restDays: Set<Int> = []
    @State private var error: String?

    private var hasArchivedCompanionship: Bool {
        model.companionDayCount(for: goal.id) > 0
            || model.companionMessages.contains { $0.goalID == goal.id && !$0.text.isEmpty }
            || model.companionMemories.contains { $0.goalID == goal.id }
            || model.adjustmentRecords.contains { $0.goalID == goal.id && $0.appliedAt != nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(goal.title).font(.title.weight(.black))
                    Text("已记录 \(model.logs.filter { $0.goalID == goal.id && $0.status == .completed }.count) 次完成")
                        .font(.subheadline).foregroundStyle(EditorialPalette.muted)
                    Button("关联已有记录") { showsHistory = true }
                        .frame(minHeight: 44)
                    if hasArchivedCompanionship {
                        Button("历史陪伴记录") { showsArchive = true }
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("goal-history-archive")
                    }
                    DisclosureGroup("执行频率与休息日") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("每周执行天数", selection: $weeklyDays) {
                                Text("尚未确定").tag(0)
                                ForEach(1...7, id: \.self) { Text("\($0) 天").tag($0) }
                            }
                            ForEach(1...7, id: \.self) { weekday in
                                Toggle("周\(["日", "一", "二", "三", "四", "五", "六"][weekday - 1])休息", isOn: Binding(
                                    get: { restDays.contains(weekday) },
                                    set: { if $0 { restDays.insert(weekday) } else { restDays.remove(weekday) } }
                                ))
                            }
                            Button("保存频率") {
                                guard weeklyDays == 0 || weeklyDays <= 7 - restDays.count else {
                                    error = "行动日多于可用天数，请调整。"; return
                                }
                                goal.weeklyTargetDays = weeklyDays == 0 ? nil : weeklyDays
                                goal.restWeekdaysCSV = restDays.sorted().map(String.init).joined(separator: ",")
                                goal.updatedAt = Date()
                                do { try model.saveJourney() } catch { self.error = error.localizedDescription }
                            }.frame(minHeight: 44)
                            Text("此设置不会修改已启用成就的条件。")
                                .font(.caption).foregroundStyle(EditorialPalette.muted)
                        }.padding(.top, 10)
                    }
                    if let plan = JourneyJSON.decode(GeneratedProjectPlan.self, from: goal.acceptedPlanJSON) {
                        DisclosureGroup("原计划与阶段") {
                            VStack(alignment: .leading, spacing: 14) {
                                Text(plan.clarifiedGoal)
                                ForEach(plan.phases) { phase in
                                    VStack(alignment: .leading) {
                                        Text(phase.title).font(.headline)
                                        Text(phase.summary).font(.caption)
                                    }
                                }
                            }.padding(.top, 10)
                        }
                    }
                    if let error { Text(error).foregroundStyle(EditorialPalette.coralText) }
                }.padding(20)
            }
            .background(EditorialPalette.paper).foregroundStyle(EditorialPalette.ink)
            .navigationTitle("目标详情").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("返回") { dismiss() }.accessibilityIdentifier("goal-detail-close") } }
            .onAppear {
                weeklyDays = goal.weeklyTargetDays ?? 0
                restDays = Set(goal.restWeekdaysCSV.split(separator: ",").compactMap { Int($0) })
            }
            .sheet(isPresented: $showsHistory) { HistoryAssociationView(goal: goal) }
            .sheet(isPresented: $showsArchive) { CompanionSheet(goalID: goal.id) }
        }
    }
}

private struct HistoryAssociationView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let goal: PersonalGoal
    @State private var selection: Set<UUID> = []
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("只会关联所选事项及其未归属的完成记录。已有个人成就会按原条件重新统计。")
                        .font(.subheadline)
                    ForEach(model.items.filter { $0.goalID == nil }) { item in
                        Toggle(item.title, isOn: Binding(get: { selection.contains(item.id) }, set: {
                            if $0 { selection.insert(item.id) } else { selection.remove(item.id) }
                        }))
                        .padding(12).background(EditorialPalette.sheet)
                    }
                    if model.items.allSatisfy({ $0.goalID != nil }) { Text("没有未关联的事项。") }
                    if let error { Text(error).foregroundStyle(EditorialPalette.coralText) }
                }.padding(20)
            }.background(EditorialPalette.paper)
            .navigationTitle("关联到：\(goal.title)").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("返回") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认关联") {
                        do { try model.associateHistory(itemIDs: selection, with: goal.id); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }.disabled(selection.isEmpty)
                }
            }
        }
    }
}
