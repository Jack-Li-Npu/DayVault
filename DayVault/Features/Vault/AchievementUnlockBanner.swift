import AudioToolbox
import DayVaultCore
import SwiftUI
import UIKit

struct AchievementUnlockBanner: View {
    let presentation: UnlockPresentation
    let dismiss: () -> Void
    let open: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @AppStorage("achievementSoundEnabled") private var soundEnabled = false
    @State private var revealed = false
    @State private var scanPosition: CGFloat = -1

    var body: some View {
        Button(action: open) {
            HStack(spacing: 13) {
                AchievementBadge(definition: presentation.definition, unlocked: true, progress: 1, size: 62)
                    .scaleEffect(revealed || reduceMotion ? 1 : 0.72)
                    .rotationEffect(.degrees(revealed || reduceMotion ? 0 : -5))
                VStack(alignment: .leading, spacing: 4) {
                    Text("vault.achievement_unlocked")
                        .font(.caption2.monospaced().weight(.black))
                        .tracking(1.2)
                        .foregroundStyle(EditorialPalette.acid)
                    Text(LocalizedStringKey(presentation.definition.titleKey))
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Rectangle()
                        .fill(EditorialPalette.coral)
                        .frame(width: revealed || reduceMotion ? 62 : 0, height: 4)
                }
                Spacer(minLength: 4)
                Text("→")
                    .font(.title3.monospaced().weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(EditorialPalette.vaultSheet)
        .overlay(alignment: .leading) {
            Rectangle().fill(EditorialPalette.acid).frame(width: 5)
        }
        .overlay {
            Rectangle().stroke(Color.white.opacity(0.34), lineWidth: 1)
        }
        .overlay {
            GeometryReader { proxy in
                Rectangle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 22)
                    .offset(x: scanPosition * (proxy.size.width + 44) - 22)
            }
            .clipped()
            .allowsHitTesting(false)
        }
        .background(EditorialPalette.coral.offset(x: 5, y: 5))
        .accessibilityLabel(accessibilityAnnouncement)
        .accessibilityHint("vault.unlock_open_hint")
        .accessibilityAction(named: Text("action.close"), dismiss)
        .onAppear(perform: beginPresentation)
        .task {
            guard !voiceOverEnabled else { return }
            do {
                try await Task.sleep(for: .seconds(2.6))
                dismiss()
            } catch {
                // The queue advancing cancels this banner's timer.
            }
        }
    }

    private func beginPresentation() {
        if reduceMotion {
            revealed = true
        } else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) { revealed = true }
            withAnimation(.easeInOut(duration: 0.48).delay(0.18)) { scanPosition = 1 }
            if UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            if soundEnabled { AudioServicesPlaySystemSound(1104) }
        }
        if voiceOverEnabled {
            UIAccessibility.post(notification: .announcement, argument: accessibilityAnnouncement)
        }
    }

    private var accessibilityAnnouncement: String {
        let prefix = NSLocalizedString("vault.achievement_unlocked", comment: "")
        let title = NSLocalizedString(presentation.definition.titleKey, comment: "")
        return "\(prefix)：\(title)"
    }
}
