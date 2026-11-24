import SwiftUI
import UserNotifications

/// Programme reminders on iPhone and iPad. The shared ReminderStore keeps them (and raises
/// `due` while Tellio is open); here they also become notifications, so they arrive when
/// Tellio is closed. While it's open, the in-app banner shows instead of the notification.
@MainActor
enum ReminderNotifications {
    private static let delegate = ForegroundDelegate()
    /// Reminders are shown this long before the programme starts, as on the Apple TV.
    private static let lead: TimeInterval = 30
    private static let prefix = "reminder|"

    static func configure() {
        UNUserNotificationCenter.current().delegate = delegate
    }

    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        sync()
    }

    /// Replaces the scheduled notifications with the current reminders of the account in use.
    static func sync() {
        let center = UNUserNotificationCenter.current()
        let reminders = ReminderStore.shared.reminders
        Task {
            let pending = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(withIdentifiers:
                pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            // iOS keeps at most 64 pending notifications.
            for reminder in reminders.prefix(60) {
                let fire = reminder.start.addingTimeInterval(-lead).timeIntervalSinceNow
                guard fire > 1 else { continue }
                let content = UNMutableNotificationContent()
                content.title = String(localized: "Starting now")
                content.body = String(localized: "\(reminder.title) on \(reminder.channelName)")
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fire, repeats: false)
                try? await center.add(UNNotificationRequest(identifier: prefix + reminder.id, content: content,
                                                            trigger: trigger))
            }
        }
    }

    /// While Tellio is open, the banner handles reminders, so the notification stays silent.
    private final class ForegroundDelegate: NSObject, UNUserNotificationCenterDelegate {
        func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification)
            async -> UNNotificationPresentationOptions {
            []
        }
    }
}

/// The banner that slides in when a reminded programme starts, with Watch.
struct ReminderBanner: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var reminders = ReminderStore.shared

    var body: some View {
        Group {
            if let due = reminders.due {
                HStack(spacing: 12) {
                    ChannelLogo(channel: due.channel, width: 52, height: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("STARTING NOW · \(due.channelName.uppercased())")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(due.title).font(.subheadline.weight(.bold)).lineLimit(2)
                    }
                    Spacer(minLength: 4)
                    Button("Watch") {
                        reminders.dismissDue()
                        ChannelPlayback.play(due.channel, in: [due.channel], settings: settings, nowPlaying: due.title)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.white)
                    .foregroundStyle(Theme.ink)
                    Button {
                        reminders.dismissDue()
                    } label: {
                        Image(systemName: "xmark").font(.footnote.weight(.bold))
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Dismiss")
                }
                .padding(12)
                .glassPanel(cornerRadius: 24)
                .padding(.horizontal, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: reminders.due)
    }
}
