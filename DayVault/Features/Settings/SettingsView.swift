import DayVaultCore
import SwiftUI
import UIKit
import WidgetKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("achievementSoundEnabled") private var achievementSoundEnabled = false
    @AppStorage("plannerAppearance") private var plannerAppearance = PlannerAppearance.dayVault.rawValue
    @AppStorage("vaultAppearance") private var vaultAppearance = VaultAppearance.obsidian.rawValue
    @AppStorage("badgeFrameAppearance") private var badgeFrameAppearance = BadgeFrameAppearance.classic.rawValue
    @AppStorage("accentHex") private var accentHex = "#49CFF5"
    @AppStorage("widgetAppearance", store: UserDefaults(suiteName: WidgetSnapshotStore.suiteName))
    private var widgetAppearance = WidgetAppearance.midnight.rawValue
    @State private var accentColor = Color(hex: UserDefaults.standard.string(forKey: "accentHex") ?? "#49CFF5")
    @State private var appIconAppearance = AppIconAppearance(
        rawValue: UIApplication.shared.alternateIconName == "AppIconEmerald" ? "emerald" :
            UIApplication.shared.alternateIconName == "AppIconGraphite" ? "graphite" : "primary"
    ) ?? .primary
    @State private var showCalendarError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("settings.integration") {
                    LabeledContent("settings.icloud", value: String(localized: "settings.icloud_value"))
                    if model.calendarEnabled {
                        Label("settings.calendar_enabled", systemImage: "checkmark.circle.fill").foregroundStyle(DayVaultPalette.success)
                        ForEach(model.availableCalendars) { calendar in
                            Toggle(isOn: Binding(
                                get: { model.selectedCalendarIDs.contains(calendar.id) },
                                set: { model.setCalendar(calendar.id, selected: $0) }
                            )) {
                                Label(calendar.title, systemImage: "calendar")
                                    .foregroundStyle(Color(hex: calendar.colorHex))
                            }
                        }
                    } else {
                        Button("settings.enable_calendar", systemImage: "calendar.badge.plus") {
                            Task {
                                await model.enableCalendar()
                                showCalendarError = model.calendarError != nil
                            }
                        }
                    }
                }
                Section("settings.feedback") {
                    Toggle("settings.haptics", isOn: $hapticsEnabled)
                    Toggle("settings.achievement_sound", isOn: $achievementSoundEnabled)
                }
                Section("settings.appearance") {
                    if entitlements.hasLifetimePro {
                        Picker("settings.planner_palette", selection: $plannerAppearance) {
                            ForEach(PlannerAppearance.allCases) { appearance in
                                Text(appearance.titleKey).tag(appearance.rawValue)
                            }
                        }
                        ColorPicker("settings.accent_color", selection: $accentColor, supportsOpacity: false)
                            .onChange(of: accentColor) { _, value in accentHex = value.hexRGB }
                        Picker("settings.vault_style", selection: $vaultAppearance) {
                            ForEach(VaultAppearance.allCases) { appearance in
                                Text(appearance.titleKey).tag(appearance.rawValue)
                            }
                        }
                        Picker("settings.badge_frame", selection: $badgeFrameAppearance) {
                            ForEach(BadgeFrameAppearance.allCases) { appearance in
                                Text(appearance.titleKey).tag(appearance.rawValue)
                            }
                        }
                        Picker("settings.widget_style", selection: $widgetAppearance) {
                            ForEach(WidgetAppearance.allCases) { appearance in
                                Text(appearance.titleKey).tag(appearance.rawValue)
                            }
                        }
                        .onChange(of: widgetAppearance) { _, _ in WidgetCenter.shared.reloadAllTimelines() }
                        if UIApplication.shared.supportsAlternateIcons {
                            Picker("settings.app_icon", selection: $appIconAppearance) {
                                ForEach(AppIconAppearance.allCases) { appearance in
                                    Text(appearance.titleKey).tag(appearance)
                                }
                            }
                            .onChange(of: appIconAppearance) { _, value in
                                UIApplication.shared.setAlternateIconName(value.assetName, completionHandler: nil)
                            }
                        }
                    } else {
                        Label("settings.pro_appearance", systemImage: "paintpalette.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("settings.pro") {
                    if entitlements.hasLifetimePro {
                        Label("settings.pro_unlocked", systemImage: "sparkles").foregroundStyle(DayVaultPalette.violet)
                    } else {
                        Text("settings.pro_description")
                        Button {
                            Task { await entitlements.purchase() }
                        } label: {
                            HStack {
                                Label("settings.buy_pro", systemImage: "sparkles")
                                Spacer()
                                Text(entitlements.product?.displayPrice ?? "$14.99")
                            }
                        }
                        Button("settings.restore") { Task { await entitlements.restore() } }
                    }
                    if let message = entitlements.errorMessage { Text(message).font(.caption).foregroundStyle(.red) }
                }
                Section("settings.privacy") {
                    Label("settings.no_analytics", systemImage: "hand.raised.fill")
                    Text("settings.privacy_description").font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("settings.title")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("action.done") { dismiss() } } }
            .alert("settings.calendar_error", isPresented: $showCalendarError) {
                Button("action.ok") { model.calendarError = nil }
            } message: { Text(model.calendarError ?? "") }
        }
    }
}
