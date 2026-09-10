import DayVaultCore
import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var reviewing = false
    @State private var celebrating = false
    @State private var completionPulseID: UUID?

    var openVault: () -> Void = {}
    var openPlanner: () -> Void = {}
    var openCompanion: () -> Void = {}
    var openGoals: () -> Void = {}
    var openCalendar: () -> Void = {}
    var openInsights: () -> Void = {}
    var openSettings: () -> Void = {}

    private var allOccurrences: [ScheduleOccurrence] { model.occurrences() }
    private var scheduled: [ScheduleOccurrence] { allOccurrences.filter { !$0.isUnscheduled } }
    private var inbox: [ScheduleOccurrence] { allOccurrences.filter(\.isUnscheduled) }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ZStack {
                EditorialBackdrop()
                VStack(spacing: 0) {
                    homeHeader
                    if let text = model.latestCompanionText, !text.isEmpty {
                        Button(action: openCompanion) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("↳").font(.subheadline.weight(.bold))
                                Text(text).font(.subheadline).lineLimit(3)
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(EditorialPalette.muted)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("home-companion-response")
                    }
                    DayDateRail(selectedDate: $model.selectedDate)
                        .padding(.top, 6)
                    if !inbox.isEmpty {
                        InboxStrip(occurrences: inbox)
                            .padding(.horizontal, 18)
                            .padding(.top, 14)
                    }
                    DayTimelineView(occurrences: scheduled, externalEvents: model.externalEvents)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                let actionLayout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
                actionLayout {
                    Button("记一件事") { model.showEditor(at: defaultStart) }
                        .buttonStyle(EditorialPrimaryButtonStyle(fill: EditorialPalette.acid, foreground: Color(hex: "#171714")))
                        .accessibilityIdentifier("home-add-item")
                    Button(action: openPlanner) {
                        Text("AI 帮我排")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(EditorialPalette.ink)
                            .frame(minWidth: 104, minHeight: 48)
                            .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home-open-planner")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(EditorialPalette.paper)
            }
            .sheet(isPresented: $reviewing, onDismiss: { model.unlockBlockingSheets.remove("day-review") }) {
                DayReviewView()
                    .onAppear { model.unlockBlockingSheets.insert("day-review") }
            }
            .task(id: model.selectedDate) { await model.refreshExternalEvents() }
            .onChange(of: model.lastCompletionFeedbackID) {
                completionPulseID = model.lastCompletionFeedbackID
            }
            .task(id: completionPulseID) {
                guard completionPulseID != nil else { return }
                celebrating = true
                do { try await Task.sleep(for: .milliseconds(750)) } catch { return }
                celebrating = false
            }
        }
    }

    private var homeHeader: some View {
        HStack(spacing: 2) {
            Button(action: openVault) {
                DayVaultAvatar(outfit: model.avatarOutfit, pose: celebrating && !reduceMotion ? .celebrate : .idle)
                    .frame(width: 51, height: 64)
                    .background(Color(hex: "#EEE9DC"))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("我的角色与成就")
            .accessibilityIdentifier("landing-avatar")
            Button(action: openCompanion) {
                OrigamiCompanion(days: model.companionDayCount(for: model.selectedGoalID), isCelebrating: celebrating)
                    .frame(width: 55, height: 58)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("折纸伙伴")
            .accessibilityHint("查看当前目标的陪伴设置与记录")
            .accessibilityIdentifier("home-open-companion")
            VStack(alignment: .leading, spacing: 3) {
                Text("今天")
                    .font(.title2.weight(.black))
                Button(action: openGoals) {
                    Text(model.selectedGoalTitle ?? "我的目标")
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .foregroundStyle(EditorialPalette.muted)
                        .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home-open-goals")
            }
            .padding(.leading, 8)
            Spacer(minLength: 0)
            Menu {
                Button("目标与挑战", action: openGoals)
                Button("calendar.title", action: openCalendar)
                Button("today.review") { reviewing = true }
                Button("insights.title", action: openInsights)
                Divider()
                Button("settings.title", action: openSettings)
            } label: {
                EditorialMenuGlyph()
            }
            .accessibilityLabel("更多")
            .accessibilityIdentifier("home-more")
        }
        .foregroundStyle(EditorialPalette.ink)
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
    }

    private var defaultStart: Date {
        if Calendar.current.isDateInToday(model.selectedDate) {
            let seconds: TimeInterval = 15 * 60
            return Date(timeIntervalSince1970: (Date().timeIntervalSince1970 / seconds).rounded(.up) * seconds)
        }
        return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: model.selectedDate) ?? model.selectedDate
    }
}

struct DayDateRail: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selectedDate: Date
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 0) {
            ForEach(-2...2, id: \.self) { offset in
                let date = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate) ?? selectedDate
                let isSelected = offset == 0
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.86)) {
                        selectedDate = date
                    }
                } label: {
                    VStack(spacing: 7) {
                        Text(date, format: .dateTime.weekday(.narrow))
                            .font(.caption2.weight(.black))
                            .foregroundStyle(isSelected ? EditorialPalette.acid : EditorialPalette.muted)
                        Text(date, format: .dateTime.day())
                            .font(.system(.title3, design: .monospaced, weight: .black))
                            .foregroundStyle(isSelected ? .white : EditorialPalette.ink)
                        Rectangle()
                            .fill(isSelected ? EditorialPalette.coral : .clear)
                            .frame(height: 4)
                            .matchedGeometryEffect(id: isSelected ? "selected-day" : "day-\(offset)", in: selection)
                    }
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(isSelected ? EditorialPalette.ink : .clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 18)
        .overlay(alignment: .bottom) {
            Rectangle().fill(EditorialPalette.ink).frame(height: 1)
                .padding(.horizontal, 18)
        }
    }
}

private struct InboxStrip: View {
    @Environment(AppModel.self) private var model
    let occurrences: [ScheduleOccurrence]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("today.inbox")
                    .font(.caption.weight(.black))
                    .tracking(1.2)
                Spacer()
                Text(String(format: "%02d", occurrences.count))
                    .font(.caption.monospacedDigit().weight(.black))
                    .foregroundStyle(EditorialPalette.coralText)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(occurrences) { occurrence in
                        Button {
                            model.complete(occurrence)
                        } label: {
                            HStack(spacing: 8) {
                                Rectangle()
                                    .stroke(EditorialPalette.ink, lineWidth: 1.5)
                                    .frame(width: 15, height: 15)
                                Text(occurrence.title)
                                    .font(.caption.weight(.bold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(EditorialPalette.ink)
                            .padding(.horizontal, 11)
                            .frame(minHeight: 42)
                            .background(EditorialPalette.sheet)
                            .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .background(EditorialPalette.acid.opacity(0.52))
        .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
    }
}

private struct DayReviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                EditorialBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("review.unfinished")
                            .font(.caption.weight(.black))
                            .tracking(1.4)
                            .foregroundStyle(EditorialPalette.coralText)
                            .padding(.bottom, 16)
                        ForEach(model.occurrences().filter { $0.status == .planned || $0.status == .active }) { occurrence in
                            reviewRow(occurrence)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("review.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("review.finish") {
                        model.finishDayReview()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func reviewRow(_ occurrence: ScheduleOccurrence) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(occurrence.title)
                .font(.headline.weight(.black))
                .foregroundStyle(EditorialPalette.ink)
            HStack(spacing: 8) {
                Button("action.complete") { model.complete(occurrence) }
                    .accessibilityIdentifier("review-complete")
                Button("action.tomorrow") {
                    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: occurrence.start) ?? occurrence.start
                    model.reschedule(occurrence, to: tomorrow, durationMinutes: occurrence.durationMinutes)
                }
                Menu("action.skip") {
                    ForEach(SkipReason.allCases, id: \.self) { reason in
                        Button(LocalizedStringKey("skip.\(reason.rawValue)")) { model.skip(occurrence, reason: reason) }
                    }
                }
                Spacer()
                Button("action.remove", role: .destructive) { model.remove(occurrence) }
            }
            .font(.caption.weight(.bold))
        }
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(EditorialPalette.rule).frame(height: 1) }
    }
}
