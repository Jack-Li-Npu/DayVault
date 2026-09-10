import DayVaultCore
import SwiftUI

struct CalendarScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var visibleMonth = Calendar.current.startOfDay(for: Date())

    private var scheduled: [ScheduleOccurrence] {
        model.occurrences().filter { !$0.isUnscheduled }
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ZStack {
                EditorialBackdrop()
                VStack(spacing: 0) {
                    CalendarScreenHeader()
                    EditorialMonthPicker(
                        visibleMonth: $visibleMonth,
                        selectedDate: $model.selectedDate,
                        compact: dynamicTypeSize.isAccessibilitySize,
                        countForDate: count(for:)
                    )
                    DayTimelineView(occurrences: scheduled, externalEvents: model.externalEvents)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button("agenda.add") { model.showEditor(at: selectedDayStart) }
                    .buttonStyle(EditorialPrimaryButtonStyle(fill: EditorialPalette.acid, foreground: Color(hex: "#171714")))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(EditorialPalette.paper)
            }
            .task(id: model.selectedDate) { await model.refreshExternalEvents() }
            .onAppear { visibleMonth = monthStart(for: model.selectedDate) }
            .onChange(of: model.selectedDate) {
                let selectedMonth = monthStart(for: model.selectedDate)
                if !Calendar.current.isDate(selectedMonth, equalTo: visibleMonth, toGranularity: .month) {
                    visibleMonth = selectedMonth
                }
            }
        }
    }

    private var selectedDayStart: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: model.selectedDate) ?? model.selectedDate
    }

    private func count(for date: Date) -> Int {
        model.occurrences(for: date).filter { !$0.isUnscheduled && $0.status != .removed }.count
    }

    private func monthStart(for date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }
}

private struct CalendarScreenHeader: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("calendar.index")
                    .font(.caption2.monospaced().weight(.black))
                    .tracking(1.4)
                    .foregroundStyle(EditorialPalette.coralText)
                Text("calendar.title")
                    .font(.title2.weight(.black))
                    .foregroundStyle(EditorialPalette.ink)
            }
            Spacer()
        }
        .padding(.leading, 18)
        .padding(.trailing, 70)
        .padding(.top, 10)
        .padding(.bottom, 2)
    }
}

private struct EditorialMonthPicker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var visibleMonth: Date
    @Binding var selectedDate: Date
    let compact: Bool
    let countForDate: (Date) -> Int

    private let calendar: Calendar = {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }()

    private var cells: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: visibleMonth),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: visibleMonth)) else {
            return []
        }
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var dates = Array(repeating: Optional<Date>.none, count: leading)
        dates.append(contentsOf: range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: first)
        }.map(Optional.some))
        let trailing = (7 - dates.count % 7) % 7
        dates.append(contentsOf: Array(repeating: nil, count: trailing))
        return dates
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return Array(symbols[1...]) + [symbols[0]]
    }

    private var displayCells: [Date?] {
        guard compact else { return cells }
        let monthDates = cells.compactMap { $0 }
        guard let first = monthDates.first else { return [] }
        let anchor = calendar.isDate(selectedDate, equalTo: visibleMonth, toGranularity: .month)
            ? selectedDate
            : first
        let weekday = calendar.component(.weekday, from: anchor)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        guard let weekStart = calendar.date(byAdding: .day, value: -leading, to: anchor) else { return [] }
        return (0..<7).map { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart),
                  calendar.isDate(date, equalTo: visibleMonth, toGranularity: .month) else { return nil }
            return date
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            monthHeader
            weekdayHeader
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(Array(displayCells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(EditorialPalette.sheet)
        .overlay(alignment: .bottom) { Rectangle().fill(EditorialPalette.ink).frame(height: 1) }
        .accessibilityIdentifier("editorial-month-picker")
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88), value: visibleMonth)
    }

    private var monthHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                Text("calendar.month_view")
                    .font(.caption2.weight(.black))
                    .tracking(1.4)
                    .foregroundStyle(EditorialPalette.coralText)
                Text(visibleMonth, format: .dateTime.year().month(.wide))
                    .font(.system(.title, design: .rounded, weight: .black))
                    .foregroundStyle(EditorialPalette.ink)
            }
            Spacer()
            HStack(spacing: 0) {
                monthButton("←", accessibilityKey: "calendar.previous_month", offset: -1)
                monthButton("→", accessibilityKey: "calendar.next_month", offset: 1)
            }
            .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(EditorialPalette.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let selected = calendar.isDate(date, inSameDayAs: selectedDate)
        let today = calendar.isDateInToday(date)
        let count = countForDate(date)
        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 4) {
                Text(verbatim: String(calendar.component(.day, from: date)))
                    .font(.system(size: compact ? 22 : 15, weight: .black, design: .monospaced))
                    .lineLimit(1)
                HStack(spacing: 2) {
                    ForEach(0..<min(count, 3), id: \.self) { _ in
                        Rectangle()
                            .fill(selected ? EditorialPalette.acid : EditorialPalette.cobalt)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .foregroundStyle(selected ? .white : EditorialPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(selected ? EditorialPalette.ink : .clear)
            .overlay {
                if today && !selected {
                    Rectangle().stroke(EditorialPalette.coral, lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(String(format: NSLocalizedString("agenda.count", comment: ""), count))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func monthButton(_ glyph: String, accessibilityKey: LocalizedStringKey, offset: Int) -> some View {
        Button {
            guard let month = calendar.date(byAdding: .month, value: offset, to: visibleMonth) else { return }
            visibleMonth = month
        } label: {
            Text(glyph)
                .font(.title3.monospaced().weight(.black))
                .foregroundStyle(EditorialPalette.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .overlay(alignment: offset < 0 ? .trailing : .leading) {
                    Rectangle().fill(EditorialPalette.ink).frame(width: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityKey)
    }
}
