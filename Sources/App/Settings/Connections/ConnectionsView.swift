import SwiftUI

/// Settings › Connections: IPTV accounts, TMDB, Trakt and addons, each with a live status.
struct ConnectionsView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var trakt = TraktSync.shared

    @State private var iptvStates: [String: ConnectionState] = [:]
    @State private var tmdb: ConnectionState = .checking("Checking…")
    @State private var addonStates: [String: ConnectionState] = [:]
    @State private var versions: [String: String] = [:]
    @State private var confirmingDelete = false

    private var languageName: String {
        LanguageOptions.tmdb.first { $0.code == settings.prefs.tmdbLanguage }?.name ?? settings.prefs.tmdbLanguage
    }

    /// Re-checks whenever a login or the addon list changes.
    private var checkKey: String {
        "\(settings.xtreamAccounts.hashValue)|\(settings.tmdbToken.count)|\(settings.addons.map(\.id).joined(separator: ","))"
    }

    var body: some View {
        SettingsPage("Connections") {
            SettingsGroup("IPTV accounts") {
                ForEach(settings.xtreamAccounts) { account in
                    NavigationLink {
                        IPTVAccountView(accountID: account.id)
                    } label: {
                        ConnectionRowLabel(title: account.displayName,
                                           icon: "antenna.radiowaves.left.and.right",
                                           state: iptvStates[account.id] ?? .checking("Checking…"),
                                           badge: settings.xtreamAccounts.count > 1 && account.id == settings.xtream.id
                                               ? "IN USE" : nil)
                    }
                    .buttonStyle(.plain)
                }
                NavigationLink {
                    IPTVAccountView(accountID: nil)
                } label: {
                    ConnectionRowLabel(title: settings.xtreamAccounts.isEmpty ? "Add IPTV account" : "Add another account",
                                       icon: "plus")
                }
                .buttonStyle(.plain)
            }
            if settings.xtreamAccounts.count > 1 {
                SettingsNote("Live TV uses one account at a time. Open an account and choose Use for Live TV.")
            }

            SettingsGroup("Accounts") {
                NavigationLink {
                    TMDBAccountView()
                } label: {
                    ConnectionRowLabel(title: "TMDB", icon: "film", state: tmdb,
                                       trailing: settings.tmdbToken.isEmpty ? "Set up" : languageName)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    TraktAccountView()
                } label: {
                    ConnectionRowLabel(title: "Trakt", icon: "checkmark.seal",
                                       state: trakt.isSignedIn
                                           ? .good(trakt.username ?? "Signed in")
                                           : .off("Not connected"),
                                       trailing: trakt.isSignedIn ? nil : "Set up")
                }
                .buttonStyle(.plain)
            }

            SettingsGroup("Addons") {
                ForEach(settings.addons) { addon in
                    NavigationLink {
                        AddonDetailView(addonID: addon.id)
                    } label: {
                        ConnectionRowLabel(title: addon.name, icon: "puzzlepiece.extension",
                                           state: addonStates[addon.id] ?? .checking("Checking…"),
                                           trailing: versions[addon.id].map { "v" + $0 })
                    }
                    .buttonStyle(.plain)
                }
                NavigationLink {
                    AddAddonView()
                } label: {
                    ConnectionRowLabel(title: "Add addon", icon: "plus")
                }
                .buttonStyle(.plain)
            }
            SettingsNote("Movies and series play from your addons. Streams are tried in the order they're listed here.")

            SettingsGroup {
                DestructiveRow(title: "Delete all logins and addons", icon: "trash") { confirmingDelete = true }
            }
        }
        .task(id: checkKey) { await check() }
        .refreshable { await check() }
        .confirmationDialog("Delete all logins and addons?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete all", role: .destructive) { settings.deleteAllConnections() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Signs out of TMDB and your IPTV accounts and removes every addon. Your favourites, folders and other settings stay.")
        }
    }

    private func check() async {
        let accounts = settings.xtreamAccounts
        let userAgent = settings.prefs.iptvUserAgent
        let addons = settings.addons
        async let tmdbResult = ConnectionCheck.tmdb(settings)
        await withTaskGroup(of: (String, ConnectionState, String?).self) { group in
            for addon in addons {
                group.addTask {
                    let (state, manifest) = await ConnectionCheck.addon(addon)
                    return (addon.id, state, manifest?.version)
                }
            }
            for await (id, state, version) in group {
                addonStates[id] = state
                if let version { versions[id] = version }
            }
        }
        await withTaskGroup(of: (String, ConnectionState).self) { group in
            for account in accounts {
                group.addTask { (account.id, await ConnectionCheck.iptv(account, userAgent: userAgent).0) }
            }
            for await (id, state) in group { iptvStates[id] = state }
        }
        tmdb = await tmdbResult
    }
}
