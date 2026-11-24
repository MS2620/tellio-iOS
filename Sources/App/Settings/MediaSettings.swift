import SwiftUI

// Settings › Live TV & Guide, Content and Streams. The values are the same preferences the
// Apple TV uses, so a restored backup carries them across.

struct LiveTVSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var reminders = ReminderStore.shared

    private static let userAgentPresets: [(String, String)] = [
        ("", "Default"),
        ("VLC/3.0.21 LibVLC/3.0.21", "VLC"),
        ("TiviMate/5.1.6 (Android 12)", "TiviMate"),
        ("IPTVSmartersPro", "IPTV Smarters"),
    ]

    private var userAgentOptions: [(String, String)] {
        var options = Self.userAgentPresets
        let current = settings.prefs.iptvUserAgent
        if !options.contains(where: { $0.0 == current }) { options.append((current, "Custom")) }
        return options
    }

    private var upcoming: [ProgrammeReminder] {
        reminders.allReminders.filter { $0.end > Date() }.sorted { $0.start < $1.start }
    }

    var body: some View {
        SettingsPage("Live TV & Guide") {
            SettingsGroup("Reminders") {
                if upcoming.isEmpty {
                    SettingsRowLabel(title: "No reminders", icon: "bell.slash")
                }
                ForEach(upcoming) { reminder in
                    HStack(spacing: 0) {
                        SettingsRowLabel(
                            title: reminder.title,
                            subtitle: "\(reminder.channelName) · \(DayFormat.label(reminder.start)) \(DayFormat.time(reminder.start))",
                            icon: "bell")
                        Button {
                            reminders.remove(reminder)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove reminder")
                        .padding(.trailing, 6)
                    }
                }
            }
            SettingsNote("Tap a programme that hasn't started in the guide, then Remind me. You're notified 30 seconds before it begins, even when Tellio is closed.")

            SettingsGroup("Layout") {
                SettingsOptionRow(title: "Default view on iPhone", icon: "square.grid.2x2",
                                  selection: $settings.prefs.liveLayout,
                                  options: LiveLayout.allCases.map { ($0, $0.label) })
                SettingsToggleRow(title: "Channel numbers", icon: "number", isOn: $settings.prefs.showChannelNumbers)
            }

            SettingsGroup("Channels") {
                SettingsToggleRow(title: "Show programme information", subtitle: "Now and next, and the guide",
                                  icon: "text.justify.left", isOn: $settings.prefs.showEPG)
                SettingsOptionRow(title: "Sort channels by", icon: "arrow.up.arrow.down",
                                  selection: $settings.prefs.channelSort,
                                  options: ChannelSort.allCases.map { ($0, $0.label) })
                SettingsToggleRow(title: "Favourites at the top", icon: "star", isOn: $settings.prefs.favouritesFirst)
                SettingsToggleRow(title: "Remember last group", icon: "arrow.uturn.backward",
                                  isOn: $settings.prefs.rememberLastCategory)
                SettingsActionRow(title: "Clear favourites", icon: "star.slash",
                                  value: "\(settings.prefs.favouriteChannelIDs.count)") {
                    settings.prefs.favouriteChannelIDs.removeAll()
                }
            }
            SettingsNote("Hide groups and channels, or build your own folders, in Settings › Content.")

            SettingsGroup("Streaming") {
                SettingsOptionRow(title: "Stream format", icon: "waveform", selection: $settings.prefs.liveFormat,
                                  options: LiveStreamFormat.allCases.map { ($0, $0.label) })
                SettingsOptionRow(title: "Channel switching", icon: "hare", selection: $settings.prefs.channelSwitching,
                                  options: ChannelSwitching.allCases.map { ($0, $0.label) })
                SettingsOptionRow(title: "Timeshift", subtitle: "Pause and rewind live TV", icon: "gobackward",
                                  selection: $settings.prefs.timeshiftMinutes,
                                  options: [(0, "Off"), (30, "30 min"), (60, "1 hour"), (120, "2 hours")])
            }
            SettingsNote("Try MPEG-TS if channels fail on HLS. Stable switching starts slower but buffers more.")

            SettingsGroup("Provider compatibility") {
                SettingsOptionRow(title: "User agent", icon: "person.badge.key",
                                  selection: $settings.prefs.iptvUserAgent, options: userAgentOptions)
                SettingsFieldRow(title: "Custom user agent", icon: "pencil", text: $settings.prefs.iptvUserAgent)
            }
            SettingsNote("Some providers only allow certain players. Change this if your login works but channels don't.")
        }
    }
}

struct ContentSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var refreshStatus: String?

    private var hiddenSummary: String {
        let groups = settings.prefs.hiddenCategoryIDs.count
        let channels = settings.prefs.hiddenChannelIDs.count
        if groups == 0 && channels == 0 { return "None hidden" }
        return "\(groups) groups, \(channels) channels hidden"
    }

    private var qualitySummary: String {
        let count = settings.prefs.qualitySortCategoryIDs.count
        return count == 0 ? "Off" : (count == 1 ? "1 group" : "\(count) groups")
    }

    var body: some View {
        SettingsPage("Content") {
            SettingsGroup("Live TV") {
                SettingsLink(title: "Groups & channels", subtitle: hiddenSummary, icon: "eye") {
                    ChannelBrowser(mode: .visibility)
                }
                SettingsLink(title: "My folders", icon: "folder.badge.plus",
                             value: "\(settings.prefs.folders.count)") {
                    FoldersSettingsView()
                }
                SettingsLink(title: "Sort by quality", subtitle: "Split groups into 4K, FHD, HD and SD folders",
                             icon: "line.3.horizontal.decrease", value: qualitySummary) {
                    QualitySortSettingsView()
                }
            }
            SettingsNote("Hide whole groups or single channels you never watch, and collect channels from any group into folders of your own. Folders appear at the top of Live TV.")

            SettingsGroup("TV guide data") {
                SettingsOptionRow(title: "Refresh guide", icon: "arrow.triangle.2.circlepath",
                                  selection: $settings.prefs.epgRefreshHours,
                                  options: [(0, "Every time Tellio opens"), (1, "Every hour"), (3, "Every 3 hours"),
                                            (6, "Every 6 hours"), (12, "Every 12 hours"), (24, "Once a day"),
                                            (-1, "Only when I ask")])
                SettingsActionRow(title: "Refresh now", icon: "arrow.clockwise", value: refreshStatus) {
                    refreshStatus = "Clearing…"
                    Task {
                        await XtreamCache.shared.clearGuide()
                        await SportsGuide.shared.clear()
                        refreshStatus = "Done"
                    }
                }
            }
            SettingsNote("Guide data is kept on this device between refreshes, so the guide opens quickly and your provider is asked less often.")

            SettingsGroup("From your IPTV provider") {
                SettingsToggleRow(title: "Show provider movies", icon: "film", isOn: $settings.prefs.showProviderMovies)
                SettingsToggleRow(title: "Show provider series", icon: "play.tv", isOn: $settings.prefs.showProviderSeries)
            }
            SettingsNote("Adds the film and series libraries that come with your IPTV login as extra rows in Browse.")

            SettingsGroup("Catalogue") {
                SettingsOptionRow(title: "Language", icon: "globe", selection: $settings.prefs.catalogueLanguage,
                                  options: LanguageOptions.catalogue)
                SettingsOptionRow(title: "Region", icon: "mappin.and.ellipse", selection: $settings.prefs.tmdbRegion,
                                  options: LanguageOptions.regions.map { ($0.code, $0.name) })
            }
            SettingsNote("Language of titles and descriptions, and the region used for cinema releases.")
        }
    }
}

struct StreamSettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        SettingsPage("Streams") {
            SettingsGroup {
                SettingsOptionRow(title: "Maximum resolution", icon: "4k.tv", selection: $settings.prefs.maxResolution,
                                  options: MaxResolution.allCases.map { ($0, $0.label) })
                SettingsOptionRow(title: "Sort streams", icon: "arrow.up.arrow.down", selection: $settings.prefs.streamSort,
                                  options: StreamSort.allCases.map { ($0, $0.label) })
                SettingsToggleRow(title: "Play the first stream automatically", icon: "play.circle",
                                  isOn: $settings.prefs.autoPlayFirstStream)
            }
            SettingsNote("Resolution is read from the addon's stream labels; streams without one are always shown.")
        }
    }
}
