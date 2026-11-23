import SwiftUI

/// Details of the programme picked in the guide: time and channel, title, description, and
/// Watch channel / Remind me.
struct ProgrammeCard: View {
    let selection: GuideSelection
    let now: Date
    var onClose: (() -> Void)? = nil
    let watch: () -> Void

    @ObservedObject private var reminders = ReminderStore.shared

    private var entry: XtreamEPGEntry? { selection.entry }
    private var isFuture: Bool { (entry?.start ?? .distantPast) > now }
    private var isReminded: Bool {
        guard let start = entry?.start else { return false }
        return reminders.isSet(channelID: selection.channel.id, start: start)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(caption)
                    .font(.caption.weight(.heavy))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                Spacer()
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.bold))
                            .frame(width: 44, height: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    // Full-size tap target without pushing the caption down.
                    .padding(-12)
                    .accessibilityLabel("Close")
                }
            }
            Text(entry?.title.nonEmpty ?? selection.channel.name)
                .font(.title3.weight(.heavy))
                .lineLimit(2)
            if let description = entry?.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            HStack(spacing: 10) {
                if isFuture, let entry, let start = entry.start, let end = entry.end {
                    Button {
                        toggleReminder(entry, start: start, end: end)
                    } label: {
                        Label(isReminded ? "Reminder set" : "Remind me",
                              systemImage: isReminded ? "bell.slash" : "bell")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.white)
                    .foregroundStyle(Theme.ink)
                }
                Button(action: watch) {
                    Label("Watch channel", systemImage: "play.fill")
                }
                .buttonStyle(.glass)
            }
            .font(.subheadline.weight(.bold))
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 22)
        // Taps anywhere on the card stay on it instead of reaching the guide underneath.
        .contentShape(.rect(cornerRadius: 22))
        .onTapGesture {}
    }

    /// "NOW · 17:30 – 19:30 · SPORTS 1" or "20:00 · SPORTS 2".
    private var caption: String {
        var parts: [String] = []
        if let start = entry?.start, let end = entry?.end {
            if start <= now && now < end {
                parts.append("NOW · \(DayFormat.time(start)) – \(DayFormat.time(end))")
            } else {
                let day = Calendar.current.isDateInToday(start) ? "" : DayFormat.label(start) + " "
                parts.append(day + DayFormat.time(start))
            }
        }
        parts.append(selection.channel.name)
        return parts.joined(separator: " · ").uppercased()
    }

    private func toggleReminder(_ entry: XtreamEPGEntry, start: Date, end: Date) {
        let channel = selection.channel
        let reminder = ProgrammeReminder(channelID: channel.id, channelName: channel.name, channelIcon: channel.icon,
                                         channelNumber: channel.number, title: entry.title, start: start, end: end)
        if isReminded {
            reminders.remove(reminder)
        } else {
            reminders.add(reminder)
            Task { await ReminderNotifications.requestPermission() }
        }
    }
}
