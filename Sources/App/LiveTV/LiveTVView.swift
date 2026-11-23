import SwiftUI

/// Live TV: group chips, the channel list with now and next, search across every channel.
struct LiveTVView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var parental = ParentalLock.shared

    @State private var categories: [XtreamCategory] = []
    @State private var qualityFolders: [String: [ChannelQuality]] = [:]
    @State private var selectedID: String?
    @State private var channels: [XtreamChannel] = []
    @State private var epg: [Int: [XtreamEPGEntry]] = [:]
    @State private var loading = false
    @State private var error: String?
    @State private var loadedAccountID: String?
    @State private var reload = 0
    @State private var now = Date()

    @State private var query = ""
    @State private var results: [XtreamChannel] = []

    @State private var showingGroups = false
    @State private var pendingGroup: LiveGroup?
    @State private var pin = ""
    @State private var wrongPIN = false
    @State private var renaming: XtreamChannel?
    @State private var newName = ""

    private var prefs: Preferences { settings.prefs }

    private var groups: [LiveGroup] {
        LiveGroups.list(categories: categories, qualityFolders: qualityFolders, prefs: prefs, parental: parental)
    }

    private var selectedGroup: LiveGroup? { groups.first { $0.id == selectedID } }

    private var shownChannels: [XtreamChannel] {
        if !query.isEmpty { return results }
        return LiveGroups.sorted(channels, in: selectedGroup, by: prefs.channelSort)
    }

    /// Reloads the channels when the group or anything that changes the list changes.
    private var channelsKey: String {
        "\(reload)|\(settings.xtream.id)|\(selectedID ?? "")|\(prefs.hiddenChannelIDs.count)|\(prefs.folders.hashValue)"
            + "|\(prefs.favouriteChannelIDs.count)|\(prefs.qualitySortCategoryIDs.sorted())|\(prefs.channelNames.hashValue)"
            + (selectedID == LiveGroup.recentID ? "|\(prefs.recentChannelIDs)" : "")
            + "|\(parental.isUnlocked)"
    }

    var body: some View {
        NavigationStack {
            Group {
                if !settings.xtream.isConfigured {
                    ContentUnavailableView {
                        Label("No IPTV account", systemImage: "tv")
                    } description: {
                        Text("Add one in Settings › Connections, or bring your Apple TV setup across from Settings.")
                    }
                } else if let error, categories.isEmpty {
                    ContentUnavailableView {
                        Label("Can't load channels", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try again") { reload += 1 }.buttonStyle(.glass)
                    }
                } else {
                    channelList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appBackground()
            .navigationTitle("Live TV")
            .searchable(text: $query, prompt: "Channels")
            .toolbar { toolbar }
        }
        .task(id: "\(settings.xtream.id)|\(reload)|\(prefs.qualitySortCategoryIDs.sorted())") { await loadGroups() }
        .task(id: channelsKey) { await loadChannels() }
        .task(id: query) { await search() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                now = Date()
            }
        }
        .sheet(isPresented: $showingGroups) {
            GroupPicker(groups: groups, selectedID: selectedID) { group in
                showingGroups = false
                select(group)
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Enter PIN", isPresented: Binding(get: { pendingGroup != nil }, set: { if !$0 { pendingGroup = nil } })) {
            SecureField("PIN", text: $pin).keyboardType(.numberPad)
            Button("Unlock") { unlock() }
            Button("Cancel", role: .cancel) { pin = "" }
        } message: {
            Text(wrongPIN ? "That PIN isn't right. Try again." : "\(pendingGroup?.name ?? "This group") is locked.")
        }
        .alert("Rename channel", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Save") { rename() }
            if let renaming, settings.prefs.channelNames[renaming.id] != nil {
                Button("Use the provider's name") { settings.prefs.channelNames[renaming.id] = nil }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your name is used everywhere and saved for this IPTV account.")
        }
    }

    // MARK: - Content

    private var channelList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                if query.isEmpty {
                    groupChips
                        .padding(.bottom, 6)
                }
                infoLine
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)

                if shownChannels.isEmpty {
                    emptyState
                        .padding(.horizontal, 20)
                        .padding(.top, 30)
                }

                ForEach(shownChannels) { channel in
                    Button {
                        play(channel)
                    } label: {
                        ChannelRow(channel: channel,
                                   number: prefs.showChannelNumbers ? channel.number : nil,
                                   favourite: prefs.favouriteChannelIDs.contains(channel.id),
                                   folderName: selectedGroup?.isMixed == true || !query.isEmpty ? channel.folderName : nil,
                                   entries: epg[channel.id],
                                   now: now,
                                   showsGuide: prefs.showEPG)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { channelMenu(channel) }
                    .padding(.horizontal, 8)
                }
            }
            .padding(.bottom, 24)
        }
        .refreshable { reload += 1 }
    }

    private var groupChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        showingGroups = true
                    } label: {
                        Label("Groups", systemImage: "list.bullet")
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.glass)

                    ForEach(groups) { group in
                        if group.id == selectedID {
                            Button { select(group) } label: { chipLabel(group) }
                                .buttonStyle(.glassProminent)
                                .tint(.white)
                                .foregroundStyle(Theme.ink)
                                .accessibilityAddTraits(.isSelected)
                                .id(group.id)
                        } else {
                            Button { select(group) } label: { chipLabel(group) }
                                .buttonStyle(.glass)
                                .id(group.id)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
            .onChange(of: selectedID) { _, id in
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    private func chipLabel(_ group: LiveGroup) -> some View {
        HStack(spacing: 5) {
            if group.locked { Image(systemName: "lock.fill").font(.caption) }
            Text(group.name).lineLimit(1)
        }
        .font(.subheadline.weight(.bold))
        .padding(.horizontal, 4)
    }

    private var infoLine: some View {
        HStack {
            Text(infoText)
            Spacer()
            if loading { ProgressView().controlSize(.small) }
        }
        .font(.footnote.weight(.bold))
        .foregroundStyle(.secondary)
    }

    private var infoText: String {
        let count = shownChannels.count
        let channelsText = count == 1 ? "1 CHANNEL" : "\(count) CHANNELS"
        if !query.isEmpty { return channelsText + " FOUND" }
        return channelsText + " · " + settings.xtream.displayName
    }

    @ViewBuilder
    private var emptyState: some View {
        if !query.isEmpty {
            Text(loading ? "Searching…" : "No channels match \u{201C}\(query)\u{201D}.")
                .foregroundStyle(.secondary)
        } else if let group = selectedGroup, group.locked, !parental.isUnlocked {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(group.name) is locked.").foregroundStyle(.secondary)
                Button("Enter PIN") { pendingGroup = group }.buttonStyle(.glass)
            }
        } else if !loading {
            Text(selectedGroup?.isFavourites == true
                 ? "Long-press a channel and choose Add to Favourites."
                 : "No channels in this group.")
                .foregroundStyle(.secondary)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if settings.xtreamAccounts.count > 1 {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(settings.xtreamAccounts) { account in
                        Button {
                            settings.switchAccount(to: account.id)
                        } label: {
                            if account.id == settings.xtream.id {
                                Label(account.displayName, systemImage: "checkmark")
                            } else {
                                Text(account.displayName)
                            }
                        }
                    }
                } label: {
                    Label("Switch account", systemImage: "person.2")
                }
            }
        }
    }

    @ViewBuilder
    private func channelMenu(_ channel: XtreamChannel) -> some View {
        if prefs.favouriteChannelIDs.contains(channel.id) {
            Button("Remove from Favourites", systemImage: "star.slash") {
                settings.prefs.favouriteChannelIDs.remove(channel.id)
            }
        } else {
            Button("Add to Favourites", systemImage: "star") {
                settings.prefs.favouriteChannelIDs.insert(channel.id)
            }
        }
        ForEach(prefs.folders) { folder in
            let inFolder = folder.channelIDs.contains(channel.id)
            Button(inFolder ? "Remove from \(folder.name)" : "Add to \(folder.name)",
                   systemImage: inFolder ? "minus.circle" : "plus.circle") {
                toggle(channel.id, inFolder: folder.id)
            }
        }
        Button("Rename…", systemImage: "pencil") {
            newName = channel.name
            renaming = channel
        }
        Button("Hide channel", systemImage: "eye.slash", role: .destructive) {
            settings.prefs.hiddenChannelIDs.insert(channel.id)
        }
    }

    // MARK: - Actions

    private func select(_ group: LiveGroup) {
        if group.locked && !parental.isUnlocked {
            pin = ""
            wrongPIN = false
            pendingGroup = group
            return
        }
        guard group.id != selectedID else { return }
        selectedID = group.id
        if prefs.rememberLastCategory { settings.prefs.lastCategoryID = group.id }
    }

    private func unlock() {
        guard let group = pendingGroup else { return }
        if parental.matches(pin) {
            parental.unlock(minutes: prefs.unlockMinutes)
            pendingGroup = nil
            pin = ""
            selectedID = group.id
        } else {
            pin = ""
            wrongPIN = true
            // Ask again.
            DispatchQueue.main.async { pendingGroup = group }
        }
    }

    private func rename() {
        guard let channel = renaming else { return }
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != channel.name else { return }
        settings.prefs.channelNames[channel.id] = name == channel.providerName ? nil : name
    }

    private func toggle(_ channelID: Int, inFolder folderID: String) {
        guard let index = settings.prefs.folders.firstIndex(where: { $0.id == folderID }) else { return }
        var folder = settings.prefs.folders[index]
        if let position = folder.channelIDs.firstIndex(of: channelID) {
            folder.channelIDs.remove(at: position)
        } else {
            folder.channelIDs.append(channelID)
        }
        settings.prefs.folders[index] = folder
    }

    private func play(_ channel: XtreamChannel) {
        let client = settings.xtreamClient
        guard let url = client.liveURL(for: channel, format: prefs.liveFormat) else { return }
        let list = shownChannels
        var recent = settings.prefs.recentChannelIDs.filter { $0 != channel.id }
        recent.insert(channel.id, at: 0)
        settings.prefs.recentChannelIDs = Array(recent.prefix(20))
        SystemPlayer.present(PlaybackRequest(
            url: url,
            title: channel.name,
            subtitle: NowNext.current(epg[channel.id], at: Date())?.title,
            isLive: true,
            httpHeaders: client.requestHeaders,
            live: LiveContext(channels: list, index: list.firstIndex(of: channel) ?? 0)
        ))
    }

    // MARK: - Loading

    private func loadGroups() async {
        guard settings.xtream.isConfigured else { return }
        if loadedAccountID != settings.xtream.id {
            // Another account: different groups and channels, so start fresh.
            loadedAccountID = settings.xtream.id
            selectedID = nil
            categories = []
            channels = []
            epg = [:]
        }
        do {
            categories = try await XtreamCache.shared.liveCategories(settings.xtreamClient)
            error = nil
            qualityFolders = await LiveGroups.qualityFolders(settings: settings)
            chooseGroupIfNeeded()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Keeps the selection if it still exists, otherwise opens the last or first unlocked group.
    private func chooseGroupIfNeeded() {
        let list = groups
        if let selectedID, list.contains(where: { $0.id == selectedID }) { return }
        if prefs.rememberLastCategory, let last = prefs.lastCategoryID,
           let group = list.first(where: { $0.id == last }), !group.locked || parental.isUnlocked {
            selectedID = last
        } else {
            selectedID = list.first { !$0.isRecent && (!$0.locked || parental.isUnlocked) }?.id ?? list.first?.id
        }
    }

    private func loadChannels() async {
        guard let group = selectedGroup, !(group.locked && !parental.isUnlocked) else {
            channels = []
            return
        }
        loading = true
        let loaded = await LiveGroups.channels(in: group, settings: settings, parental: parental)
        guard !Task.isCancelled else { return }
        channels = loaded
        loading = false
        await loadGuide(for: LiveGroups.sorted(loaded, in: group, by: prefs.channelSort))
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            results = []
            return
        }
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        loading = true
        defer { loading = false }
        let all = (try? await XtreamCache.shared.liveStreams(settings.xtreamClient)) ?? []
        let found = all.filter { channel in
            settings.isVisible(channel)
                && !parental.isLocked(categoryID: channel.categoryID ?? "", prefs: prefs)
                && channel.name.localizedStandardContains(text)
        }
        guard !Task.isCancelled else { return }
        results = Array(found.prefix(150))
        await loadGuide(for: results)
    }

    /// Downloads listings for the first few hundred channels that don't have them yet.
    private func loadGuide(for list: [XtreamChannel]) async {
        guard prefs.showEPG else { return }
        let pending = list.prefix(300).map(\.id).filter { epg[$0] == nil }
        await NowNext.load(pending, client: settings.xtreamClient) { batch in
            epg.merge(batch) { _, new in new }
        }
    }
}

/// Every group in a searchable list, for accounts with too many to scroll through as chips.
private struct GroupPicker: View {
    let groups: [LiveGroup]
    let selectedID: String?
    let choose: (LiveGroup) -> Void
    @State private var filter = ""

    private var shown: [LiveGroup] {
        filter.isEmpty ? groups : groups.filter { $0.name.localizedStandardContains(filter) }
    }

    var body: some View {
        NavigationStack {
            List(shown) { group in
                Button {
                    choose(group)
                } label: {
                    HStack {
                        Label(group.name, systemImage: group.locked ? "lock.fill" : group.icon)
                        Spacer()
                        if group.id == selectedID {
                            Image(systemName: "checkmark").fontWeight(.bold)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $filter, placement: .navigationBarDrawer(displayMode: .always), prompt: "Groups")
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
