import SwiftUI

// Settings › Player, Subtitles, Home screen, Sports and Calendar.

struct PlayerSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    private static let seekOptions = [5, 10, 15, 30, 60, 120]

    var body: some View {
        SettingsPage("Player") {
            SettingsGroup("Audio language") {
                SettingsOptionRow(title: "Preferred audio", icon: "speaker.wave.2",
                                  selection: $settings.prefs.audioLanguage,
                                  options: LanguageOptions.audio.map { ($0.code, $0.name) })
            }

            SettingsGroup("Skipping") {
                SettingsOptionRow(title: "Skip back", icon: "gobackward", selection: $settings.prefs.seekBackSeconds,
                                  options: Self.seekOptions.map { ($0, String(localized: "\($0) seconds")) })
                SettingsOptionRow(title: "Skip forward", icon: "goforward", selection: $settings.prefs.seekForwardSeconds,
                                  options: Self.seekOptions.map { ($0, String(localized: "\($0) seconds")) })
            }
            SettingsNote("The skip buttons in the player, and double-tapping the left or right side of the picture.")

            SettingsGroup("Audio") {
                SettingsToggleRow(title: "Dialogue boost", icon: "person.wave.2", isOn: $settings.prefs.dialogueBoost)
                SettingsToggleRow(title: "Night mode", subtitle: "Quieter loud scenes", icon: "moon",
                                  isOn: $settings.prefs.nightMode)
            }
            SettingsNote("These are shared with the Apple TV, where they also turn off Dolby Atmos passthrough while on.")
        }
    }
}

struct SubtitleSettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        SettingsPage("Subtitles") {
            SettingsGroup {
                SettingsToggleRow(title: "Turn subtitles on automatically", icon: "captions.bubble",
                                  isOn: $settings.prefs.autoSubtitles)
                SettingsOptionRow(title: "Subtitle language", icon: "globe", selection: $settings.prefs.subtitleLanguage,
                                  options: LanguageOptions.audio.map { ($0.code, $0.name) })
            }
            SettingsNote("When on, subtitles in this language are picked automatically if the video has them.")

            SettingsGroup("Appearance") {
                SettingsOptionRow(title: "Size", icon: "textformat.size", selection: $settings.prefs.subtitleSize,
                                  options: SubtitleSize.allCases.map { ($0, $0.label) })
                Text("The quick brown fox jumps over the lazy dog")
                    .font(.system(size: settings.prefs.subtitleSize.points * 0.48, weight: .semibold))
                    .shadow(color: .black, radius: 3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 14)
                    .background(.black.opacity(0.35))
            }
        }
    }
}

/// Home rows: drag to reorder, switch to show or hide.
struct HomeScreenSettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        List {
            Section {
                ForEach(settings.homeRowOrder) { row in
                    Toggle(row.title, isOn: Binding(
                        get: { !settings.prefs.hiddenHomeRows.contains(row.rawValue) },
                        set: { shown in
                            if shown {
                                settings.prefs.hiddenHomeRows.remove(row.rawValue)
                            } else {
                                settings.prefs.hiddenHomeRows.insert(row.rawValue)
                            }
                        }))
                }
                .onMove { from, to in
                    var order = settings.homeRowOrder
                    order.move(fromOffsets: from, toOffset: to)
                    settings.prefs.homeRows = order.map(\.rawValue)
                }
            } header: {
                Text("Rows, top to bottom")
            } footer: {
                Text("Drag the handles to reorder. Continue Watching is always first. My List, Favourite Channels and My Teams only appear once they have something in them. The order is shared with the Apple TV.")
            }

            Section {
                Button("Reset to default") {
                    settings.prefs.homeRows = HomeRow.allCases.map(\.rawValue)
                    settings.prefs.hiddenHomeRows = []
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Home screen")
    }
}

struct SportsSettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        SettingsPage("Sports") {
            SettingsGroup {
                SettingsOptionRow(title: "Show fixtures for the next", icon: "calendar",
                                  selection: $settings.prefs.sportsDaysAhead,
                                  options: [(7, "7 days"), (14, "14 days"), (30, "30 days")])
                SettingsLink(title: "My Teams", icon: "star", value: "\(settings.prefs.favouriteTeams.count)") {
                    TeamsManagerView()
                }
            }
            SettingsNote("Fixtures cover every competition a team plays in, not just the league you picked it from.")
        }
    }
}

struct CalendarSettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        SettingsPage("Calendar") {
            SettingsGroup {
                SettingsOptionRow(title: "Episodes per series", icon: "list.number",
                                  selection: $settings.prefs.calendarEpisodesPerSeries,
                                  options: [(1, "Next only"), (2, "Next 2"), (3, "Next 3"), (5, "Next 5")])
                SettingsOptionRow(title: "Look ahead", icon: "calendar", selection: $settings.prefs.calendarDaysAhead,
                                  options: [(30, "30 days"), (60, "60 days"), (90, "90 days"), (180, "6 months")])
            }
            SettingsNote("The calendar lists upcoming episodes of the series in My List. Episodes that have already aired are never shown.")
        }
    }
}
