import SwiftUI

/// Settings, opened from the gear on Home.
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var backup = BackupService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SettingsPage("Settings") {
                NavigationLink {
                    RestoreView()
                } label: {
                    RestoreCard()
                }
                .buttonStyle(.plain)

                SettingsGroup("Accounts") {
                    SettingsLink(title: "Connections", subtitle: "IPTV, addons, Trakt, TMDB", icon: "link",
                                 value: connectionCount) {
                        ComingSoonPage(title: "Connections")
                    }
                    SettingsLink(title: "Backup & restore", icon: "externaldrive",
                                 value: backup.isConfigured ? "Ready" : "Set up") {
                        BackupView()
                    }
                }

                SettingsGroup("Watching") {
                    SettingsLink(title: "Content", subtitle: "Groups, folders, Sort by quality",
                                 icon: "square.stack.3d.up") {
                        ComingSoonPage(title: "Content")
                    }
                    SettingsLink(title: "Playback", icon: "play.rectangle") {
                        ComingSoonPage(title: "Playback")
                    }
                    SettingsLink(title: "Parental controls", icon: "lock",
                                 value: settings.prefs.parentalControlsOn ? "On" : "Off") {
                        ComingSoonPage(title: "Parental controls")
                    }
                    SettingsLink(title: "Appearance", icon: "paintbrush",
                                 value: settings.prefs.backgroundStyle.label) {
                        AppearanceView()
                    }
                }

                SettingsGroup("About") {
                    SettingsInfoRow(title: "Version", icon: "info.circle", value: Self.version)
                    SettingsToggleRow(title: "Send crash reports",
                                      subtitle: CrashReporting.isAvailable
                                          ? "Anonymous; no logins, links or watch history"
                                          : "Not in this build",
                                      icon: "ant",
                                      isOn: Binding(
                                          get: { settings.prefs.crashReports },
                                          set: { on in
                                              settings.prefs.crashReports = on
                                              CrashReporting.apply(enabled: on)
                                          }))
                }
                SettingsNote("When Tellio crashes, a report is sent the next time it opens. It holds where in Tellio's code it crashed and the iOS version and model, nothing else.")
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
    }

    /// IPTV accounts plus addons, or nothing when there are none.
    private var connectionCount: String? {
        let count = settings.xtreamAccounts.count + settings.addons.count
        return count == 0 ? nil : "\(count)"
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}

/// The white card at the top of Settings: bring the Apple TV's setup across with a backup code.
private struct RestoreCard: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "icloud.and.arrow.down")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Theme.ink, in: .rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text("Bring your Apple TV setup").font(.headline.weight(.heavy))
                Text("Restore with your 8-character backup code")
                    .font(.footnote)
                    .foregroundStyle(Theme.ink.opacity(0.75))
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.footnote.weight(.bold))
        }
        .foregroundStyle(Theme.ink)
        .padding(16)
        .background(.white, in: .rect(cornerRadius: 20))
        .contentShape(.rect)
    }
}
