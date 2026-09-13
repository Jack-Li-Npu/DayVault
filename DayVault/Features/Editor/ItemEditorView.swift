import DayVaultCore
import SwiftUI

struct ItemEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ScheduleItemDraft
    @State private var recurrenceKind = RecurrenceKind.none
    @State private var reminderMinutes = -1
    @State private var showsAdvancedOptions = false
    @State private var errorKey: String?
    @State private var initializedGoal = false

    init(initialDate: Date) {
        _draft = State(initialValue: ScheduleItemDraft(plannedStart: initialDate))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EditorialBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        editorHeader
                        essentialFields
                        advancedDisclosure

                        if showsAdvancedOptions {
                            advancedFields
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { saveBar }
            .onAppear {
                if !initializedGoal {
                    draft.goalID = model.selectedGoalID
                    initializedGoal = true
                }
            }
            .alert("editor.error", isPresented: Binding(
                get: { errorKey != nil },
                set: { if !$0 { errorKey = nil } }
            )) {
                Button("action.ok") { errorKey = nil }
            } message: {
                if let errorKey { Text(LocalizedStringKey(errorKey)) }
            }
        }
    }

    private var editorHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            DayVaultMark(size: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text("editor.index")
                    .font(.caption2.monospaced().weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(EditorialPalette.cobalt)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .dynamicTypeSize(.small ... .xxxLarge)

                Text("editor.new_item")
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(EditorialPalette.ink)
            }

            Spacer(minLength: 12)

            Button(action: dismiss.callAsFunction) {
                EditorialCloseGlyph()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("action.cancel")
        }
    }

    private var essentialFields: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                EditorIndexLabel(index: "01", titleKey: "editor.what")

                TextField("editor.title_prompt", text: $draft.title, axis: .vertical)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(EditorialPalette.ink)
                    .lineLimit(1...3)
                    .textInputAutocapitalization(.sentences)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(minHeight: 58)
                    .background(EditorialPalette.sheet)
                    .overlay {
                        Rectangle()
                            .stroke(EditorialPalette.ink, lineWidth: 1)
                    }
            }

            VStack(alignment: .leading, spacing: 10) {
                EditorIndexLabel(index: "02", titleKey: "editor.when")

                VStack(spacing: 0) {
                    dateRow
                }
                .padding(.horizontal, 16)
                .background(EditorialPalette.sheet)
                .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
            }

            if !model.goals.isEmpty {
                HStack(spacing: 8) {
                    Menu {
                        Button("不关联目标") { draft.goalID = nil }
                        ForEach(model.goals) { goal in
                            Button(goal.title) { draft.goalID = goal.id }
                        }
                    } label: {
                        Text(draft.goalID.flatMap { id in model.goals.first { $0.id == id }?.title }.map { "计入：\($0)" } ?? "不关联目标")
                            .font(.caption)
                            .foregroundStyle(EditorialPalette.muted)
                            .lineLimit(2)
                            .frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("editor-goal")
                    Spacer(minLength: 0)
                    if draft.goalID != nil {
                        Button("不关联") { draft.goalID = nil }
                            .font(.caption.weight(.bold))
                            .frame(minHeight: 44)
                    }
                }
            }
        }
    }

    private var dateRow: some View {
        EditorFieldRow(titleKey: "editor.date") {
            if draft.timePrecision == .inbox {
                Text("待安排 · 不指定日期")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(EditorialPalette.muted)
            } else {
                EditorCompactDatePicker(
                    titleKey: "editor.date",
                    selection: $draft.plannedStart,
                    displayedComponents: .date,
                    displayValue: draft.plannedStart.formatted(date: .numeric, time: .omitted),
                    width: 168,
                    isDisabled: false
                )
            }
        }
    }

    private var timeRow: some View {
        EditorFieldRow(titleKey: "editor.time") {
            EditorCompactDatePicker(
                titleKey: "editor.time",
                selection: $draft.plannedStart,
                displayedComponents: .hourAndMinute,
                displayValue: draft.plannedStart.formatted(date: .omitted, time: .shortened),
                width: 108,
                isDisabled: draft.isUnscheduled
            )
        }
    }

    private var durationRow: some View {
        EditorFieldRow(titleKey: "editor.duration") {
            HStack(spacing: 4) {
                Button {
                    draft.durationMinutes -= 1
                } label: {
                    EditorialStepGlyph(isAddition: false)
                }
                .buttonStyle(.plain)
                .disabled(draft.durationMinutes <= 1)
                .accessibilityLabel("editor.duration_decrease")

                Text(String(format: NSLocalizedString("agenda.minutes", comment: ""), draft.durationMinutes))
                    .font(.body.monospacedDigit().weight(.bold))
                    .foregroundStyle(EditorialPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(minWidth: 72)

                Button {
                    draft.durationMinutes += 1
                } label: {
                    EditorialStepGlyph(isAddition: true)
                }
                .buttonStyle(.plain)
                .disabled(draft.durationMinutes >= 720)
                .accessibilityLabel("editor.duration_increase")
            }
        }
    }

    private var categoryField: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorIndexLabel(index: "03", titleKey: "editor.category")

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96, maximum: 160), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                CategoryChip(
                    title: NSLocalizedString("editor.no_category", comment: ""),
                    color: EditorialPalette.ink,
                    isSelected: draft.categoryID == nil
                ) {
                    draft.categoryID = nil
                }

                ForEach(model.categories) { category in
                    CategoryChip(
                        title: NSLocalizedString(category.name, comment: ""),
                        color: EditorialPalette.category(category),
                        isSelected: draft.categoryID == category.id
                    ) {
                        draft.categoryID = category.id
                    }
                }
            }
        }
    }

    private var advancedDisclosure: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                showsAdvancedOptions.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("editor.advanced")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(EditorialPalette.ink)
                    Text("时间、分类、重复与提醒")
                        .font(.caption)
                        .foregroundStyle(EditorialPalette.muted)
                }

                Spacer(minLength: 12)

                EditorialDisclosureGlyph(isExpanded: showsAdvancedOptions)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(EditorialPalette.acid.opacity(0.72))
        .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
        .accessibilityIdentifier("editor-advanced-toggle")
        .accessibilityValue(showsAdvancedOptions ? "editor.expanded" : "editor.collapsed")
    }

    private var advancedFields: some View {
        VStack(alignment: .leading, spacing: 22) {
            timingModePicker
            if draft.timePrecision == .timed {
                VStack(spacing: 0) {
                    timeRow
                    EditorHairline()
                    durationRow
                }
                .padding(.horizontal, 16)
                .background(EditorialPalette.sheet)
                .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
            }
            categoryField
            if !model.templates.isEmpty {
                templatePicker
            }

            VStack(alignment: .leading, spacing: 10) {
                EditorIndexLabel(index: "04", titleKey: "editor.options")

                VStack(spacing: 0) {
                    priorityRow
                    EditorHairline()
                    recurrenceRow

                    if recurrenceKind == .selectedWeekdays {
                        EditorHairline()
                        WeekdaySelector(selection: weekdaysBinding)
                            .padding(.vertical, 8)
                    }

                    if draft.timePrecision == .timed {
                        EditorHairline()
                        reminderRow
                    }
                }
                .padding(.horizontal, 16)
                .background(EditorialPalette.sheet)
                .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
            }

            VStack(alignment: .leading, spacing: 10) {
                EditorIndexLabel(index: "05", titleKey: "editor.notes")

                TextField("editor.notes_placeholder", text: $draft.notes, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(14)
                    .frame(minHeight: 96, alignment: .topLeading)
                    .background(EditorialPalette.sheet)
                    .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }

                EditorToggleRow(
                    titleKey: "editor.save_template",
                    isOn: $draft.saveAsTemplate
                )
                .padding(.horizontal, 16)
                .background(EditorialPalette.sheet)
                .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
            }
        }
    }

    private var timingModePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("时间设置")
                .font(.caption.weight(.bold))
                .foregroundStyle(EditorialPalette.muted)
            HStack(spacing: 8) {
                timingChoice("仅日期", precision: .dateOnly)
                timingChoice("具体时间", precision: .timed)
                timingChoice("待安排", precision: .inbox)
            }
            Text(timingModeHint)
                .font(.caption)
                .foregroundStyle(EditorialPalette.muted)
        }
    }

    private var timingModeHint: String {
        switch draft.timePrecision {
        case .dateOnly: "仅指定日期，不设置时刻或提醒。"
        case .timed: "按指定时间安排；提醒默认关闭。"
        case .inbox: "不指定日期，不发送提醒。"
        }
    }

    private func timingChoice(_ title: String, precision: ScheduleTimePrecision) -> some View {
        Button {
            if precision == .timed && draft.timePrecision != .timed {
                let calendar = Calendar.current
                let minutes = calendar.component(.hour, from: Date()) * 60 + calendar.component(.minute, from: Date())
                let startMinutes = calendar.isDateInToday(draft.plannedStart) ? min(23 * 60 + 59, ((minutes + 14) / 15) * 15) : 9 * 60
                draft.plannedStart = calendar.date(bySettingHour: startMinutes / 60, minute: startMinutes % 60, second: 0, of: draft.plannedStart) ?? draft.plannedStart
            }
            draft.timePrecision = precision
            draft.isUnscheduled = precision == .inbox
            if precision != .timed { reminderMinutes = -1; draft.reminderLead = nil }
        } label: {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(draft.timePrecision == precision ? Color(hex: "#171714") : EditorialPalette.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(draft.timePrecision == precision ? EditorialPalette.acid : EditorialPalette.sheet)
                .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("editor-time-mode-\(precision.rawValue)")
        .accessibilityAddTraits(draft.timePrecision == precision ? .isSelected : [])
    }

    private var templatePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorIndexLabel(index: "T", titleKey: "editor.templates")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(model.templates) { template in
                        EditorTemplateChip(
                            title: template.title,
                            durationMinutes: template.durationMinutes
                        ) {
                            apply(template)
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    private var priorityRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("editor.priority")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EditorialPalette.muted)

            HStack(spacing: 7) {
                ForEach(ItemPriority.allCases, id: \.self) { priority in
                    EditorChoiceChip(
                        title: NSLocalizedString("priority.\(priority.rawValue)", comment: ""),
                        isSelected: draft.priority == priority
                    ) {
                        draft.priority = priority
                    }
                }
            }
        }
        .padding(.vertical, 12)
    }

    private var recurrenceRow: some View {
        EditorMenuRow(
            titleKey: "editor.recurrence",
            value: NSLocalizedString("recurrence.\(recurrenceKind.rawValue)", comment: "")
        ) {
            ForEach(RecurrenceKind.allCases, id: \.self) { kind in
                Button {
                    recurrenceKind = kind
                } label: {
                    Text(NSLocalizedString("recurrence.\(kind.rawValue)", comment: ""))
                }
            }
        }
    }

    private var reminderRow: some View {
        EditorMenuRow(
            titleKey: "editor.reminder",
            value: reminderLabel
        ) {
            Button(NSLocalizedString("reminder.none", comment: "")) { reminderMinutes = -1 }
            Button(NSLocalizedString("reminder.at_start", comment: "")) { reminderMinutes = 0 }
            ForEach([5, 10, 15, 30, 60], id: \.self) { value in
                Button(String(format: NSLocalizedString("reminder.minutes_before", comment: ""), value)) {
                    reminderMinutes = value
                }
            }
        }
    }

    private var saveBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(EditorialPalette.rule)
                .frame(height: 1)

            Button("editor.save_item", action: save)
                .buttonStyle(EditorialPrimaryButtonStyle(
                    fill: trimmedTitle.isEmpty ? EditorialPalette.muted : EditorialPalette.cobalt,
                    foreground: trimmedTitle.isEmpty ? EditorialPalette.paper : .white
                ))
                .disabled(trimmedTitle.isEmpty)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .background(EditorialPalette.paper)
    }

    private var reminderLabel: String {
        switch reminderMinutes {
        case -1:
            NSLocalizedString("reminder.none", comment: "")
        case 0:
            NSLocalizedString("reminder.at_start", comment: "")
        default:
            String(format: NSLocalizedString("reminder.minutes_before", comment: ""), reminderMinutes)
        }
    }

    private var trimmedTitle: String {
        draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var weekdaysBinding: Binding<Set<Int>> {
        Binding(
            get: { draft.recurrenceRule.weekdays },
            set: { draft.recurrenceRule.weekdays = $0 }
        )
    }

    private func apply(_ template: QuickTemplate) {
        draft.title = template.title
        draft.notes = template.notes
        draft.categoryID = template.categoryID
        draft.durationMinutes = template.durationMinutes
        draft.priority = template.priority
        draft.templateID = template.id
    }

    private func save() {
        draft.recurrenceRule.kind = recurrenceKind
        draft.isUnscheduled = draft.timePrecision == .inbox
        draft.reminderLead = draft.timePrecision == .timed ? ReminderLead(rawValue: reminderMinutes) : nil
        Task {
            if let error = await model.addItem(draft, isPro: entitlements.hasLifetimePro) {
                errorKey = error
            } else {
                dismiss()
            }
        }
    }
}

private struct EditorTemplateChip: View {
    let title: String
    let durationMinutes: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                Text("T")
                    .font(.caption2.monospaced().weight(.black))
                    .foregroundStyle(EditorialPalette.cobalt)
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(EditorialPalette.ink)
                    .lineLimit(2)
                Text(String(format: NSLocalizedString("agenda.minutes", comment: ""), durationMinutes))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(EditorialPalette.muted)
            }
            .frame(width: 132, alignment: .leading)
            .frame(minHeight: 88, alignment: .leading)
            .padding(12)
            .background(EditorialPalette.sheet)
            .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityHint("editor.apply_template")
    }
}

private struct EditorIndexLabel: View {
    let index: String
    let titleKey: LocalizedStringKey

    var body: some View {
        HStack(spacing: 8) {
            Text(index)
                .font(.caption2.monospaced().weight(.black))
                .foregroundStyle(EditorialPalette.cobalt)
            Text(titleKey)
                .font(.caption.weight(.bold))
                .foregroundStyle(EditorialPalette.muted)
                .textCase(.uppercase)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct EditorFieldRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let titleKey: LocalizedStringKey
    @ViewBuilder let content: Content

    init(titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.titleKey = titleKey
        self.content = content()
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel
                    content.frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, 8)
            } else {
                HStack(spacing: 12) {
                    fieldLabel
                    Spacer(minLength: 12)
                    content
                }
            }
        }
        .frame(minHeight: 54)
    }

    private var fieldLabel: some View {
        Text(titleKey)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(EditorialPalette.muted)
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct EditorCompactDatePicker: View {
    let titleKey: LocalizedStringKey
    @Binding var selection: Date
    let displayedComponents: DatePickerComponents
    let displayValue: String
    let width: CGFloat
    let isDisabled: Bool

    var body: some View {
        ZStack {
            DatePicker(
                titleKey,
                selection: $selection,
                displayedComponents: displayedComponents
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(EditorialPalette.cobalt)
            .frame(width: width, height: 44)
            .contentShape(Rectangle())
            .dynamicTypeSize(.small ... .xxxLarge)
            .disabled(isDisabled)

            HStack(spacing: 7) {
                Text(displayValue)
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .foregroundStyle(EditorialPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .dynamicTypeSize(.small ... .xxxLarge)

                EditorialArrowGlyph(color: EditorialPalette.cobalt)
                    .scaleEffect(0.7)
                    .rotationEffect(.degrees(90))
            }
            .padding(.horizontal, 10)
            .frame(width: width, height: 44)
            .background(EditorialPalette.paper)
            .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
        .frame(width: width, height: 44)
        .opacity(isDisabled ? 0.45 : 1)
    }
}

private struct EditorMenuRow<MenuContent: View>: View {
    let titleKey: LocalizedStringKey
    let value: String
    @ViewBuilder let menuContent: MenuContent

    init(
        titleKey: LocalizedStringKey,
        value: String,
        @ViewBuilder content: () -> MenuContent
    ) {
        self.titleKey = titleKey
        self.value = value
        self.menuContent = content()
    }

    var body: some View {
        Menu {
            menuContent
        } label: {
            HStack(spacing: 12) {
                Text(titleKey)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EditorialPalette.muted)
                Spacer(minLength: 12)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(EditorialPalette.ink)
                    .multilineTextAlignment(.trailing)
                EditorialArrowGlyph(color: EditorialPalette.cobalt)
                    .frame(width: 22, height: 22)
                    .rotationEffect(.degrees(90))
            }
            .frame(minHeight: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct EditorToggleRow: View {
    let titleKey: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                Text(titleKey)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EditorialPalette.muted)
                Spacer(minLength: 12)
                ZStack {
                    Rectangle()
                        .fill(isOn ? EditorialPalette.cobalt : .clear)
                        .frame(width: 44, height: 28)
                        .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }

                    Rectangle()
                        .fill(isOn ? Color.white : EditorialPalette.ink)
                        .frame(width: 18, height: 18)
                        .offset(x: isOn ? 8 : -8)
                }
                .frame(width: 48, height: 44)
            }
            .frame(minHeight: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? "editor.on" : "editor.off")
    }
}

private struct CategoryChip: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Rectangle()
                    .fill(isSelected ? EditorialPalette.paper : color)
                    .frame(width: 9, height: 9)
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? EditorialPalette.paper : EditorialPalette.ink)
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(isSelected ? EditorialPalette.ink : EditorialPalette.sheet)
            .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct EditorChoiceChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(isSelected ? Color.white : EditorialPalette.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isSelected ? EditorialPalette.cobalt : EditorialPalette.paper)
                .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct EditorialCloseGlyph: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(EditorialPalette.sheet)
                .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
            Rectangle()
                .fill(EditorialPalette.ink)
                .frame(width: 18, height: 2)
                .rotationEffect(.degrees(45))
            Rectangle()
                .fill(EditorialPalette.ink)
                .frame(width: 18, height: 2)
                .rotationEffect(.degrees(-45))
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
}

private struct EditorialDisclosureGlyph: View {
    let isExpanded: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(EditorialPalette.ink)
                .frame(width: 18, height: 2)
            Rectangle()
                .fill(EditorialPalette.ink)
                .frame(width: 18, height: 2)
                .rotationEffect(.degrees(isExpanded ? 0 : 90))
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }
}

private struct EditorialStepGlyph: View {
    let isAddition: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(EditorialPalette.paper)
                .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
            Rectangle()
                .fill(EditorialPalette.ink)
                .frame(width: 14, height: 2)
            if isAddition {
                Rectangle()
                    .fill(EditorialPalette.ink)
                    .frame(width: 14, height: 2)
                    .rotationEffect(.degrees(90))
            }
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
}

private struct EditorHairline: View {
    var body: some View {
        Rectangle()
            .fill(EditorialPalette.rule)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

private struct WeekdaySelector: View {
    @Binding var selection: Set<Int>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { weekday in
                    let name = Calendar.current.veryShortWeekdaySymbols[weekday - 1]
                    Button(name) {
                        if selection.contains(weekday) {
                            selection.remove(weekday)
                        } else {
                            selection.insert(weekday)
                        }
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(selection.contains(weekday) ? Color.white : EditorialPalette.ink)
                    .frame(width: 44, height: 44)
                    .background(selection.contains(weekday) ? EditorialPalette.cobalt : EditorialPalette.paper)
                    .overlay { Rectangle().stroke(EditorialPalette.ink, lineWidth: 1) }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection.contains(weekday) ? .isSelected : [])
                }
            }
        }
    }
}
