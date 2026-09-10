import Charts
import DayVaultCore
import SwiftUI

struct InsightsView: View {
    @Environment(AppModel.self) private var model
    @Environment(EntitlementStore.self) private var entitlements
    @State private var showSettings = false

    private var completed: [OccurrenceLog] { model.logs.filter { $0.status == .completed } }
    private var rangeDays: Int { entitlements.hasLifetimePro ? 3650 : 30 }

    var body: some View {
        NavigationStack {
            ZStack {
                PlannerBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        summaryCards
                        completionChart
                        accuracyCard
                        balanceCard
                    }
                    .padding()
                }
            }
            .navigationTitle("insights.title")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("settings.title", systemImage: "gearshape.fill") { showSettings = true }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 10) {
            MetricCard(title: "insights.completed", value: "\(completed.count)", symbol: "checkmark.circle.fill", color: DayVaultPalette.success)
            MetricCard(title: "insights.actual", value: "\(actualRecordedCount)", symbol: "timer", color: DayVaultPalette.cyan)
            MetricCard(title: "insights.streak", value: "\(currentStreak)", symbol: "flame.fill", color: DayVaultPalette.warning)
        }
    }

    private var completionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("insights.last_30_days").font(.headline)
                Spacer()
                if !entitlements.hasLifetimePro { Label("Pro", systemImage: "sparkles").font(.caption).foregroundStyle(DayVaultPalette.violet) }
            }
            Chart(completionData) { point in
                BarMark(x: .value("Day", point.day, unit: .day), y: .value("Completed", point.count))
                    .foregroundStyle(DayVaultPalette.cyan.gradient)
                    .cornerRadius(3)
            }
            .chartXAxis(.hidden)
            .frame(height: 170)
        }
        .padding()
        .glassCard()
    }

    private var accuracyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("insights.planned_actual").font(.headline)
            if entitlements.hasLifetimePro {
                HStack {
                    Gauge(value: accuracyScore) {
                        Text("insights.accuracy")
                    } currentValueLabel: {
                        Text("\(Int(accuracyScore * 100))%")
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(DayVaultPalette.violet)
                    Text("insights.accuracy_explanation").font(.subheadline).foregroundStyle(.secondary)
                }
            } else {
                ProLockedRow(text: "insights.pro_accuracy")
            }
        }
        .padding()
        .glassCard()
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("insights.balance").font(.headline)
            if entitlements.hasLifetimePro {
                ForEach(balanceData, id: \.group) { value in
                    HStack {
                        Text(LocalizedStringKey("balance.\(value.group.rawValue)")).frame(width: 70, alignment: .leading)
                        ProgressView(value: value.ratio).tint(groupColor(value.group))
                        Text(value.ratio, format: .percent.precision(.fractionLength(0))).font(.caption.monospacedDigit())
                    }
                }
            } else {
                ProLockedRow(text: "insights.pro_balance")
            }
        }
        .padding()
        .glassCard()
    }

    private var actualRecordedCount: Int { completed.filter { $0.actualStart != nil && $0.actualEnd != nil }.count }

    private var currentStreak: Int { model.currentScheduledDayStreak() }

    private var completionData: [CompletionPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lower = calendar.date(byAdding: .day, value: -min(29, rangeDays - 1), to: today) ?? today
        let grouped = Dictionary(grouping: completed.compactMap(\.completedAt).filter { $0 >= lower }) { calendar.startOfDay(for: $0) }
        return (0..<30).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset - 29, to: today) else { return nil }
            return CompletionPoint(day: day, count: grouped[day]?.count ?? 0)
        }
    }

    private var accuracyScore: Double {
        let values = completed.compactMap { log -> Double? in
            guard log.timePrecision == .timed, let item = model.items.first(where: { $0.id == log.scheduleItemID }),
                  let start = log.actualStart, let end = log.actualEnd else { return nil }
            let actual = end.timeIntervalSince(start)
            let planned = TimeInterval((log.overrideDurationMinutes ?? item.plannedDurationMinutes) * 60)
            return max(0, 1 - min(1, abs(actual - planned) / max(planned, 60)))
        }
        return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    private var balanceData: [(group: BalanceGroup, ratio: Double)] {
        let itemByID = Dictionary(uniqueKeysWithValues: model.items.map { ($0.id, $0) })
        var values: [BalanceGroup: Int] = [:]
        for log in completed {
            guard log.timePrecision == .timed, let item = itemByID[log.scheduleItemID], let category = model.category(for: item.categoryID) else { continue }
            values[category.balanceGroup, default: 0] += log.overrideDurationMinutes ?? item.plannedDurationMinutes
        }
        let total = max(1, values.values.reduce(0, +))
        return BalanceGroup.allCases.map { ($0, Double(values[$0, default: 0]) / Double(total)) }
    }

    private func groupColor(_ group: BalanceGroup) -> Color {
        switch group { case .focus: DayVaultPalette.cyan; case .care: DayVaultPalette.success; case .rest: DayVaultPalette.vaultGold; case .other: DayVaultPalette.violet }
    }
}

private struct CompletionPoint: Identifiable {
    let day: Date
    let count: Int
    var id: Date { day }
}

private struct MetricCard: View {
    let title: LocalizedStringKey
    let value: String
    let symbol: String
    let color: Color
    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(title).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 94)
        .glassCard()
    }
}

private struct ProLockedRow: View {
    let text: LocalizedStringKey
    var body: some View {
        Label(text, systemImage: "lock.fill")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
    }
}
