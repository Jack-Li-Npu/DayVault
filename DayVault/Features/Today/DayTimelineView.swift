import DayVaultCore
import SwiftUI

/// Kept under its original type name so widgets and navigation do not need to
/// know that the old hourly timeline is now a compact, ordered daybook.
struct DayTimelineView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let occurrences: [ScheduleOccurrence]
    let externalEvents: [ExternalCalendarEvent]

    @State private var selectedOccurrence: ScheduleOccurrence?
    @State private var selectedExternalEvent: ExternalCalendarEvent?
    @State private var appeared = false

    private var entries: [AgendaEntry] {
        let tasks = occurrences
            .filter { $0.status != .removed }
            .map(AgendaEntry.task)
        let calendar = externalEvents.map(AgendaEntry.external)
        return (tasks + calendar).sorted {
            if $0.start == $1.start { return $0.id < $1.id }
            return $0.start < $1.start
        }
    }

    private var conflictIDs: Set<String> {
        let active = occurrences.filter { $0.timePrecision == .timed && ($0.status == .planned || $0.status == .active) }
        var result = Set<String>()
        for firstIndex in active.indices {
            for secondIndex in active.indices where secondIndex > firstIndex {
                let first = active[firstIndex]
                let second = active[secondIndex]
                if first.start < second.end && second.start < first.end {
                    result.insert(first.id)
                    result.insert(second.id)
                }
            }
        }
        return result
    }

    private var nextOccurrenceID: String? {
        if let active = occurrences.first(where: { $0.status == .active }) { return active.id }
        let candidates = occurrences.filter { $0.status == .planned }
        if Calendar.current.isDateInToday(model.selectedDate) {
            return candidates.first(where: { $0.timePrecision == .dateOnly || $0.end >= Date() })?.id ?? candidates.first?.id
        }
        return candidates.first?.id
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                summary
                    .padding(.bottom, 14)

                if entries.isEmpty {
                    emptyState
                } else {
                    agendaList
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("agenda-list")
        .sheet(item: $selectedOccurrence, onDismiss: { model.unlockBlockingSheets.remove("occurrence-actions") }) { occurrence in
            OccurrenceActionSheet(occurrence: occurrence)
                .onAppear { model.unlockBlockingSheets.insert("occurrence-actions") }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedExternalEvent) { event in
            ExternalCalendarEventView(eventIdentifier: event.id)
        }
        .onAppear { revealRows() }
        .onChange(of: model.selectedDate) {
            appeared = false
            revealRows()
        }
    }

    private var summary: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("agenda.sequence")
                    .font(.caption.weight(.black))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(EditorialPalette.muted)
                Text(model.selectedDate, format: .dateTime.month(.wide).day())
                    .font(.system(.title2, design: .rounded, weight: .black))
                    .foregroundStyle(EditorialPalette.ink)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: NSLocalizedString("agenda.count", comment: ""), entries.count))
                    .font(.subheadline.weight(.bold))
                let completed = occurrences.filter { $0.status == .completed }.count
                Text(String(format: NSLocalizedString("agenda.completed", comment: ""), completed))
                    .font(.caption)
                    .foregroundStyle(EditorialPalette.muted)
            }
        }
    }

    private var agendaList: some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                switch entry {
                case let .task(occurrence):
                    AgendaTaskRow(
                        ordinal: index + 1,
                        occurrence: occurrence,
                        category: model.category(for: occurrence.categoryID),
                        isNext: occurrence.id == nextOccurrenceID,
                        hasConflict: conflictIDs.contains(occurrence.id),
                        open: { selectedOccurrence = occurrence },
                        complete: { model.complete(occurrence) }
                    )
                case let .external(event):
                    ExternalAgendaRow(ordinal: index + 1, event: event) {
                        selectedExternalEvent = event
                    }
                }
            }
        }
        .background(EditorialPalette.sheet)
        .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
        .background(EditorialPalette.ink.offset(x: 5, y: 5))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared || reduceMotion ? 0 : 8)
        .animation(
            reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.34, dampingFraction: 0.88),
            value: appeared
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("00")
                .font(.system(size: 58, weight: .black, design: .monospaced))
                .foregroundStyle(EditorialPalette.coralText)
                .accessibilityHidden(true)
            Text("today.empty.title")
                .font(.system(.title, design: .rounded, weight: .black))
                .foregroundStyle(EditorialPalette.ink)
            Text("today.empty.message")
                .font(.body)
                .foregroundStyle(EditorialPalette.muted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorialCard(radius: 0)
    }

    private func revealRows() {
        if reduceMotion {
            appeared = true
        } else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.88).delay(0.05)) {
                appeared = true
            }
        }
    }
}

private enum AgendaEntry: Identifiable {
    case task(ScheduleOccurrence)
    case external(ExternalCalendarEvent)

    var id: String {
        switch self {
        case let .task(occurrence): "task-\(occurrence.id)"
        case let .external(event): "external-\(event.id)"
        }
    }

    var start: Date {
        switch self {
        case let .task(occurrence): occurrence.timePrecision == .dateOnly ? Calendar.current.startOfDay(for: occurrence.start) : occurrence.start
        case let .external(event): event.start
        }
    }
}

private struct AgendaTaskRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let ordinal: Int
    let occurrence: ScheduleOccurrence
    let category: ScheduleCategory?
    let isNext: Bool
    let hasConflict: Bool
    let open: () -> Void
    let complete: () -> Void

    private var foreground: Color {
        isNext ? .white : EditorialPalette.ink
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Button(action: open) {
                HStack(alignment: .top, spacing: 14) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        Text(String(format: "%02d", ordinal))
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundStyle(isNext ? EditorialPalette.acid : EditorialPalette.muted)
                            .lineLimit(1)
                            .frame(width: 34, alignment: .leading)
                    }

                    Rectangle()
                        .fill(EditorialPalette.category(category))
                        .frame(width: 5, height: 58)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(occurrence.title)
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundStyle(foreground)
                            .strikethrough(occurrence.status == .completed, color: foreground)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                            .multilineTextAlignment(.leading)

                        Group {
                            if occurrence.displayStart == nil {
                                HStack(spacing: 6) {
                                    Text("当天完成")
                                    occurrenceState
                                }
                            } else if dynamicTypeSize.isAccessibilitySize {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(occurrence.start, style: .time)
                                    HStack(spacing: 6) {
                                        Text(String(format: NSLocalizedString("agenda.minutes", comment: ""), occurrence.durationMinutes))
                                        occurrenceState
                                    }
                                }
                                .fixedSize(horizontal: false, vertical: true)
                            } else {
                                HStack(spacing: 6) {
                                    Text(occurrence.start, style: .time)
                                    Text("/")
                                    Text(String(format: NSLocalizedString("agenda.minutes", comment: ""), occurrence.durationMinutes))
                                    occurrenceState
                                }
                            }
                        }
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundStyle(isNext ? .white.opacity(0.72) : EditorialPalette.muted)
                    }
                    Spacer(minLength: 6)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("agenda.open_actions")

            TaskCompletionControl(
                completed: occurrence.status == .completed,
                foreground: isNext ? EditorialPalette.acid : EditorialPalette.ink,
                completedMark: isNext ? Color(hex: "#171714") : EditorialPalette.paper,
                action: complete
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(minHeight: 88)
        .background(isNext ? EditorialPalette.cobalt : EditorialPalette.sheet)
        .overlay(alignment: .bottom) {
            Rectangle().fill(isNext ? Color.white.opacity(0.22) : EditorialPalette.rule).frame(height: 1)
        }
        .opacity(occurrence.status == .skipped ? 0.48 : 1)
    }

    private var accessibilityLabel: String {
        let time = occurrence.displayStart?.formatted(date: .omitted, time: .shortened) ?? "当天完成"
        return "\(ordinal)，\(occurrence.title)，\(time)"
    }

    @ViewBuilder
    private var occurrenceState: some View {
        if occurrence.status == .active {
            Text("agenda.active")
                .foregroundStyle(EditorialPalette.acid)
        } else if occurrence.status == .skipped {
            Text("agenda.skipped")
        } else if hasConflict {
            Text("agenda.conflict")
                .foregroundStyle(isNext ? EditorialPalette.acid : EditorialPalette.coralText)
        }
    }
}

private struct TaskCompletionControl: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let completed: Bool
    let foreground: Color
    let completedMark: Color
    let action: () -> Void
    @State private var drawn = false

    var body: some View {
        Button {
            guard !completed else { return }
            action()
        } label: {
            ZStack {
                Rectangle()
                    .fill(completed ? foreground : .clear)
                    .overlay { Rectangle().stroke(foreground, lineWidth: 2) }
                    .frame(width: 28, height: 28)
                EditorialCheckmark()
                    .trim(from: 0, to: drawn || completed ? 1 : 0)
                    .stroke(
                        completed ? completedMark : foreground,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .square, lineJoin: .miter)
                    )
                    .frame(width: 18, height: 18)
            }
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(completed ? "agenda.completed_label" : "action.complete")
        .disabled(completed)
        .onAppear { drawn = completed }
        .onChange(of: completed) {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                drawn = completed
            }
        }
    }
}

private struct ExternalAgendaRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let ordinal: Int
    let event: ExternalCalendarEvent
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(alignment: .top, spacing: 14) {
                if !dynamicTypeSize.isAccessibilitySize {
                    Text(String(format: "%02d", ordinal))
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(EditorialPalette.muted)
                        .lineLimit(1)
                        .frame(width: 34, alignment: .leading)
                }
                Rectangle()
                    .fill(Color(hex: event.colorHex))
                    .frame(width: 5, height: 58)
                VStack(alignment: .leading, spacing: 7) {
                    Text(event.title)
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(EditorialPalette.ink)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("agenda.external")
                                Text(event.start, style: .time)
                            }
                        } else {
                            HStack(spacing: 6) {
                                Text("agenda.external")
                                Text("/")
                                Text(event.start, style: .time)
                            }
                        }
                    }
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(EditorialPalette.muted)
                }
                Spacer()
                if !dynamicTypeSize.isAccessibilitySize {
                    Text("agenda.external_badge")
                        .font(.caption2.monospaced().weight(.black))
                        .foregroundStyle(EditorialPalette.ink)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(minHeight: 88)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle().fill(EditorialPalette.rule).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(event.title)，\(event.start.formatted(date: .omitted, time: .shortened))，\(NSLocalizedString("agenda.external", comment: ""))")
    }
}

private struct OccurrenceActionSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let occurrence: ScheduleOccurrence

    @State private var adjustedStart: Date
    @State private var adjustedDuration: Int
    @State private var showExport = false
    @State private var showExportNotice = false

    init(occurrence: ScheduleOccurrence) {
        self.occurrence = occurrence
        _adjustedStart = State(initialValue: occurrence.start)
        _adjustedDuration = State(initialValue: occurrence.durationMinutes)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EditorialBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        actionHeader
                        primaryAction
                        scheduleEditor
                        secondaryActions
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("action.done") { dismiss() }
                        .foregroundStyle(EditorialPalette.ink)
                }
            }
            .alert("calendar.export.title", isPresented: $showExportNotice) {
                Button("action.cancel", role: .cancel) {}
                Button("action.continue") { showExport = true }
            } message: {
                if occurrence.timePrecision == .dateOnly {
                    Text("将创建一个全天日历副本，与本 App 独立。后续修改不会互相同步。")
                } else {
                    Text("calendar.export.independent_copy")
                }
            }
            .sheet(isPresented: $showExport) {
                CalendarExportView(occurrence: occurrence)
            }
        }
    }

    private var actionHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("item.actions")
                .font(.caption.weight(.black))
                .tracking(1.4)
                .foregroundStyle(EditorialPalette.coralText)
            Text(occurrence.title)
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .foregroundStyle(EditorialPalette.ink)
            Text(scheduleDescription)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(EditorialPalette.muted)
        }
    }

    private var scheduleDescription: String {
        guard let start = occurrence.displayStart else {
            return occurrence.isUnscheduled ? "待安排" : occurrence.start.formatted(date: .abbreviated, time: .omitted) + " · 当天完成"
        }
        return start.formatted(date: .abbreviated, time: .shortened) + " / " + String(format: NSLocalizedString("agenda.minutes", comment: ""), occurrence.durationMinutes)
    }

    @ViewBuilder
    private var primaryAction: some View {
        if occurrence.status == .active {
            Button("action.stop_complete") {
                model.complete(occurrence)
                dismiss()
            }
            .buttonStyle(EditorialPrimaryButtonStyle(fill: EditorialPalette.coral, foreground: .white))
        } else if occurrence.status != .completed {
            HStack(spacing: 10) {
                Button("action.start") {
                    model.start(occurrence)
                    dismiss()
                }
                .buttonStyle(EditorialPrimaryButtonStyle(fill: EditorialPalette.ink, foreground: EditorialPalette.paper))
                Button("action.complete") {
                    model.complete(occurrence)
                    dismiss()
                }
                .buttonStyle(EditorialPrimaryButtonStyle(fill: EditorialPalette.acid, foreground: Color(hex: "#171714")))
            }
        }
    }

    private var scheduleEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("agenda.reschedule")
                .font(.headline.weight(.black))
            DatePicker("editor.start", selection: $adjustedStart, displayedComponents: occurrence.timePrecision == .timed ? [.date, .hourAndMinute] : [.date])
                .datePickerStyle(.compact)
            if occurrence.timePrecision == .timed {
                Stepper(value: $adjustedDuration, in: 15...480, step: 15) {
                    HStack {
                        Text("editor.duration")
                        Spacer()
                        Text(String(format: NSLocalizedString("agenda.minutes", comment: ""), adjustedDuration))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(EditorialPalette.muted)
                    }
                }
            }
            Button("agenda.save_changes") {
                model.reschedule(occurrence, to: adjustedStart, durationMinutes: adjustedDuration)
                dismiss()
            }
            .buttonStyle(EditorialPrimaryButtonStyle(fill: EditorialPalette.cobalt, foreground: .white))
        }
        .padding(16)
        .editorialCard(radius: 0)
    }

    private var secondaryActions: some View {
        VStack(spacing: 0) {
            Menu {
                ForEach(SkipReason.allCases, id: \.self) { reason in
                    Button(LocalizedStringKey("skip.\(reason.rawValue)")) {
                        model.skip(occurrence, reason: reason)
                        dismiss()
                    }
                }
            } label: {
                actionRow("action.skip", detail: "action.choose_reason")
            }
            Button { showExportNotice = true } label: {
                actionRow("action.export", detail: occurrence.timePrecision == .dateOnly ? "全天独立副本" : occurrence.isUnscheduled ? "先设置日期" : "action.calendar_copy")
            }
            .disabled(occurrence.isUnscheduled || occurrence.timePrecision == .inbox)
            Button(role: .destructive) {
                model.remove(occurrence)
                dismiss()
            } label: {
                actionRow("action.remove", detail: "action.remove_detail", destructive: true)
            }
        }
        .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
    }

    private func actionRow(_ title: LocalizedStringKey, detail: LocalizedStringKey, destructive: Bool = false) -> some View {
        HStack {
            Text(title).font(.body.weight(.bold))
            Spacer()
            Text(detail).font(.caption).foregroundStyle(EditorialPalette.muted)
            Text("→").font(.body.monospaced().weight(.bold))
        }
        .foregroundStyle(destructive ? EditorialPalette.coral : EditorialPalette.ink)
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(EditorialPalette.sheet)
        .overlay(alignment: .bottom) { Rectangle().fill(EditorialPalette.rule).frame(height: 1) }
        .contentShape(Rectangle())
    }
}
