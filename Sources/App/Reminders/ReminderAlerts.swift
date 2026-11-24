import SwiftUI
import UserNotifications

/// Programme and match reminders on iPhone and iPad. The shared ReminderStore keeps them (and
/// raises `due` or `dueMatch` while Tellio is open); here they also become notifications, so they
/// arrive when Tellio is closed. While it's open, the in-app banner shows instead.
/// Tapping a programme's notification opens Live TV, where its banner offers Watch now; tapping a
/// match's opens its page in Sports, to pick a channel. Nothing starts playing by itself.
@MainActor
enum ReminderNotifications {
    private static let delegate = Delegate()
    private static let programmePrefix = "reminder|"
    private static let matchPrefix = "match|"

    static func configure() {
        UNUserNotificationCenter.current().delegate = delegate
    }

    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        sync()
    }

    private struct Pending {
        let identifier: String
        let fire: Date
        let content: UNMutableNotificationContent
    }

    /// Replaces the scheduled notifications with the current reminders (the programmes of the
    /// account in use, and every match).
    static func sync() {
        let center = UNUserNotificationCenter.current()
        let store = ReminderStore.shared
        let lead = ReminderStore.lead
        var pending: [Pending] = []
        for reminder in store.reminders {
            let fire = reminder.start.addingTimeInterval(-lead)
            let content = content(start: reminder.start, fire: fire,
                                  body: String(localized: "\(reminder.title) on \(reminder.channelName)"))
            content.userInfo = ["kind": "programme", "id": reminder.id]
            pending.append(Pending(identifier: programmePrefix + reminder.id, fire: fire, content: content))
        }
        for reminder in store.matches {
            let fire = reminder.start.addingTimeInterval(-lead)
            let content = content(start: reminder.start, fire: fire,
                                  body: "\(reminder.title) · \(reminder.fixture.competition)")
            var info: [String: Any] = ["kind": "match", "id": reminder.id]
            // Its copy of the fixture, in case the reminder has gone by the time it's tapped.
            if let data = try? JSONEncoder().encode(reminder.fixture) { info["fixture"] = data }
            content.userInfo = info
            pending.append(Pending(identifier: matchPrefix + reminder.id, fire: fire, content: content))
        }
        // iOS keeps at most 64 pending notifications: the soonest 60.
        let upcoming = pending.filter { $0.fire.timeIntervalSinceNow > 1 }.sorted { $0.fire < $1.fire }.prefix(60)
        Task {
            let scheduled = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(withIdentifiers: scheduled.map(\.identifier).filter {
                $0.hasPrefix(programmePrefix) || $0.hasPrefix(matchPrefix)
            })
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            for item in upcoming {
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: item.fire.timeIntervalSinceNow, repeats: false)
                try? await center.add(UNNotificationRequest(identifier: item.identifier, content: item.content,
                                                            trigger: trigger))
            }
        }
    }

    /// "Starts in 10 min" or "Starting now", as it will be when the notification arrives.
    private static func content(start: Date, fire: Date, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = ReminderLead.minutesUntil(start, from: fire).map { String(localized: "Starts in \($0) min") }
            ?? String(localized: "Starting now")
        content.body = body
        content.sound = .default
        return content
    }

    /// A tapped notification: Live TV for a programme, the match's page for a match.
    fileprivate static func open(kind: String, id: String, savedFixture: Data?) {
        let store = ReminderStore.shared
        switch kind {
        case "match":
            let saved = savedFixture.flatMap { try? JSONDecoder().decode(Fixture.self, from: $0) }
            let reminded = store.matches.first { $0.id == id }?.fixture
                ?? (store.dueMatch?.id == id ? store.dueMatch?.fixture : nil)
            guard let fixture = LiveScores.shared.fixture(id: id) ?? reminded ?? saved else { return }
            store.opened(matchID: id)
            AppRouter.shared.openMatch(fixture)
        default:
            // The banner comes up there with Watch now, while the programme hasn't ended.
            AppRouter.shared.openLiveTV()
        }
    }

    private final class Delegate: NSObject, UNUserNotificationCenterDelegate {
        /// While Tellio is open, the banner handles reminders, so the notification stays silent.
        func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification)
            async -> UNNotificationPresentationOptions {
            []
        }

        func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
            let info = response.notification.request.content.userInfo
            guard let kind = info["kind"] as? String, let id = info["id"] as? String else { return }
            let saved = info["fixture"] as? Data
            await MainActor.run { ReminderNotifications.open(kind: kind, id: id, savedFixture: saved) }
        }
    }
}

/// The banner that slides in shortly before a reminded programme or match: Watch now for a
/// programme, Where to watch for a match (its page, to pick a channel).
struct ReminderBanner: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var reminders = ReminderStore.shared

    private var dueID: String? { reminders.due?.id ?? reminders.dueMatch.map { "match|\($0.id)" } }

    var body: some View {
        Group {
            if let due = reminders.due {
                card(start: due.start, source: due.channelName, title: due.title,
                     action: String(localized: "Watch now")) {
                    ChannelLogo(channel: due.channel, width: 52, height: 34)
                } perform: {
                    reminders.dismissDue()
                    ChannelPlayback.play(due.channel, in: [due.channel], settings: settings, nowPlaying: due.title)
                }
            } else if let match = reminders.dueMatch {
                card(start: match.start, source: match.fixture.competition, title: match.title,
                     action: String(localized: "Where to watch")) {
                    MatchBadge(fixture: match.fixture)
                } perform: {
                    reminders.dismissDueMatch()
                    AppRouter.shared.openMatch(LiveScores.shared.fixture(id: match.id) ?? match.fixture)
                }
            }
        }
        .animation(.spring(duration: 0.35), value: dueID)
    }

    private func card<Badge: View>(start: Date, source: String, title: String, action: String,
                                   @ViewBuilder badge: () -> Badge,
                                   perform: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            badge()
            VStack(alignment: .leading, spacing: 2) {
                TimelineView(.periodic(from: .now, by: 15)) { _ in
                    Text("\(ReminderLead.heading(start)) · \(source.uppercased())")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(title).font(.subheadline.weight(.bold)).lineLimit(2)
            }
            Spacer(minLength: 4)
            Button(action, action: perform)
                .buttonStyle(.glassProminent)
                .tint(.white)
                .foregroundStyle(Theme.ink)
            Button {
                reminders.dismissDue()
                reminders.dismissDueMatch()
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

/// The two teams' badges, or a chequered flag for a race, at channel-logo size.
private struct MatchBadge: View {
    let fixture: Fixture

    var body: some View {
        Group {
            if fixture.isRace {
                Image(systemName: "flag.checkered").font(.title3.weight(.bold))
            } else {
                HStack(spacing: -8) {
                    TeamLogo(url: fixture.home?.logo, size: 28)
                    TeamLogo(url: fixture.away?.logo, size: 28)
                }
            }
        }
        .frame(width: 52, height: 34)
    }
}
