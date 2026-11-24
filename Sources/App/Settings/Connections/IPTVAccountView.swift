import SwiftUI

/// Settings › Connections › an IPTV account: login, status, Use for Live TV, remove.
/// Fields are edited as a draft and saved with Save, so the login isn't re-checked on every key.
struct IPTVAccountView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    /// The account to show; nil adds a new one.
    let accountID: String?
    @State private var createdID: String?
    @State private var draft = XtreamAccount()
    @State private var loaded = false
    /// Xtream Codes login, or an M3U playlist link.
    @State private var isPlaylist = false

    @State private var state: ConnectionState = .off("Not set up")
    @State private var info: XtreamAccountInfo?
    @State private var channelCount: Int?
    @State private var groupCount: Int?
    @State private var confirmingRemove = false

    private var currentID: String? { accountID ?? createdID }

    /// The saved account (nil while adding a new one that isn't saved yet).
    private var saved: XtreamAccount? {
        guard let id = currentID else { return nil }
        if settings.xtream.id == id { return settings.xtream }
        return settings.xtreamAccounts.first { $0.id == id }
    }

    private var isInUse: Bool {
        guard let saved else { return false }
        return settings.xtream.isConfigured && settings.xtream.id == saved.id
    }

    private var hasChanges: Bool { trimmed(draft) != saved }

    var body: some View {
        SettingsPage(saved?.displayName ?? "IPTV account") {
            ConnectionHeader(icon: "antenna.radiowaves.left.and.right", state: state)

            if let saved, saved.isConfigured, !isInUse {
                SettingsGroup {
                    Button {
                        settings.switchAccount(to: saved.id)
                    } label: {
                        SettingsRowLabel(title: "Use for Live TV", icon: "checkmark")
                    }
                    .buttonStyle(.plain)
                }
            }

            SettingsGroup("Login") {
                SettingsOptionRow(title: "Type", icon: "list.bullet", selection: $isPlaylist,
                                  options: [(false, "Xtream Codes"), (true, "M3U playlist")])
                SettingsFieldRow(title: "Name", icon: "textformat", prompt: "Optional", text: $draft.name)
                    .textInputAutocapitalization(.words)
                if isPlaylist {
                    SettingsFieldRow(title: "Playlist address", icon: "list.bullet.rectangle",
                                     prompt: "http://…/playlist.m3u", keyboard: .URL, text: $draft.playlistURL)
                    SettingsFieldRow(title: "Guide address", icon: "calendar", prompt: "From the playlist",
                                     keyboard: .URL, text: $draft.guideURL)
                } else {
                    SettingsFieldRow(title: "Server", icon: "globe", prompt: "http://server:port", keyboard: .URL,
                                     text: $draft.server)
                    SettingsFieldRow(title: "Username", icon: "person", text: $draft.username)
                    SettingsFieldRow(title: "Password", icon: "lock", secure: true, text: $draft.password)
                }
            }
            if isPlaylist {
                SettingsNote("Use the playlist link from your provider; it usually ends in .m3u or .m3u8. The guide comes from the link inside the playlist, so only enter one if your provider gives it separately. Live channels are read; films and series in the playlist are left out.")
            } else {
                SettingsNote("The name is only for you; without one the server is shown.")
            }

            if let info, info.signedIn {
                SettingsGroup("Status") {
                    // A playlist has no account to report on, only its channels.
                    if saved?.isM3U != true {
                        SettingsInfoRow(title: "Account", icon: "person.badge.shield.checkmark",
                                        value: info.status.capitalized)
                    }
                    if let connections = info.connectionsText {
                        SettingsInfoRow(title: "Connections", icon: "person.2", value: connections)
                    }
                    if let expires = info.expires {
                        SettingsInfoRow(title: "Expires", icon: "calendar",
                                        value: expires.formatted(date: .abbreviated, time: .omitted))
                    }
                    if let channelCount, let groupCount {
                        SettingsInfoRow(title: "Live TV", icon: "tv",
                                        value: String(localized: "\(channelCount) channels · \(groupCount) groups"))
                    }
                    SettingsInfoRow(title: "TV guide", icon: "list.bullet.rectangle", value: refreshText)
                }
            }

            if let saved, saved.isConfigured {
                SettingsGroup {
                    Button {
                        Task { await check() }
                    } label: {
                        SettingsRowLabel(title: "Test connection", icon: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    DestructiveRow(title: "Remove account", icon: "trash") { confirmingRemove = true }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", systemImage: "checkmark") { save() }
                    .disabled(!trimmed(draft).isConfigured || !hasChanges)
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let saved { draft = saved }
            isPlaylist = draft.isM3U
        }
        .task(id: saved) { await check() }
        .confirmationDialog("Remove this IPTV account?", isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button("Remove account", role: .destructive) { remove() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(settings.xtreamAccounts.count > 1
                 ? "Its favourites, folders and reminders are removed too."
                 : "Live TV and Sports channels stop working until you add a login again.")
        }
    }

    private func trimmed(_ account: XtreamAccount) -> XtreamAccount {
        var account = account
        account.name = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
        account.server = account.server.trimmingCharacters(in: .whitespacesAndNewlines)
        account.username = account.username.trimmingCharacters(in: .whitespacesAndNewlines)
        account.playlistURL = account.playlistURL.trimmingCharacters(in: .whitespacesAndNewlines)
        account.guideURL = account.guideURL.trimmingCharacters(in: .whitespacesAndNewlines)
        // Only the chosen type's details are kept, so the account reads as that type.
        if isPlaylist {
            account.server = ""
            account.username = ""
            account.password = ""
        } else {
            account.playlistURL = ""
            account.guideURL = ""
        }
        return account
    }

    private func save() {
        let account = trimmed(draft)
        draft = account
        if currentID != nil {
            settings.updateAccount(account)
        } else {
            settings.addAccount(account)
            createdID = account.id
        }
    }

    private func remove() {
        guard let saved else { return }
        let wasInUse = isInUse
        settings.removeAccount(id: saved.id)
        if wasInUse {
            Task {
                await XtreamCache.shared.clearGuide()
                await SportsGuide.shared.clear()
            }
        }
        dismiss()
    }

    private var refreshText: String {
        switch settings.prefs.epgRefreshHours {
        case ..<0: return "Refreshed when you ask"
        case 0: return "Every launch"
        case 1: return "Every hour"
        case 24: return "Once a day"
        case let hours: return String(localized: "Every \(hours) hours")
        }
    }

    private func check() async {
        guard let account = saved, account.isConfigured else {
            state = .off("Not set up")
            info = nil
            return
        }
        state = .checking("Checking…")
        let userAgent = settings.prefs.iptvUserAgent
        let (newState, newInfo) = await ConnectionCheck.iptv(account, userAgent: userAgent)
        state = newState
        info = newInfo
        guard newInfo?.signedIn == true else {
            channelCount = nil
            groupCount = nil
            return
        }
        let client = XtreamClient(account: account, userAgent: userAgent)
        channelCount = (try? await XtreamCache.shared.liveStreams(client))?.count
        groupCount = (try? await XtreamCache.shared.liveCategories(client))?.count
    }
}
