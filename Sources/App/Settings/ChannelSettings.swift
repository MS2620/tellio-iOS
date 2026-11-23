import SwiftUI

/// The provider's groups, each opening its channels. Used to hide groups and channels, and to
/// pick channels for a folder.
struct ChannelBrowser: View {
    enum Mode: Hashable {
        case visibility
        case folder(String)
    }

    let mode: Mode
    @EnvironmentObject private var settings: AppSettings
    @State private var categories: [XtreamCategory] = []
    @State private var byGroup: [String: [XtreamChannel]] = [:]
    @State private var loading = true
    @State private var error: String?
    @State private var filter = ""

    private var prefs: Preferences { settings.prefs }

    private var title: String {
        if case .folder(let id) = mode, let folder = prefs.folders.first(where: { $0.id == id }) {
            return "Add to \(folder.name)"
        }
        return "Groups & channels"
    }

    /// Picking for a folder only offers what isn't hidden.
    private var shownGroups: [XtreamCategory] {
        let groups = mode == .visibility ? categories : categories.filter { !prefs.hiddenCategoryIDs.contains($0.id) }
        return filter.isEmpty ? groups : groups.filter { $0.name.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        List {
            if let error {
                Text(error).foregroundStyle(.secondary)
            } else if loading {
                ProgressView().frame(maxWidth: .infinity)
            }
            if mode == .visibility && !loading && error == nil {
                Section {
                    Button("Show everything") {
                        settings.prefs.hiddenCategoryIDs.removeAll()
                        settings.prefs.hiddenChannelIDs.removeAll()
                    }
                } footer: {
                    Text("Switch a group off to hide it everywhere, or open it to hide single channels.")
                }
            }
            Section {
                ForEach(shownGroups) { group in
                    let channels = byGroup[group.id] ?? []
                    if mode == .visibility {
                        let hidden = prefs.hiddenCategoryIDs.contains(group.id)
                        NavigationLink {
                            ChannelList(group: group, channels: channels, mode: mode)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.name).foregroundStyle(hidden ? .secondary : .primary)
                                    Text("\(channels.count) channels").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Toggle(group.name, isOn: Binding(
                                    get: { !hidden },
                                    set: { shown in
                                        if shown {
                                            settings.prefs.hiddenCategoryIDs.remove(group.id)
                                        } else {
                                            settings.prefs.hiddenCategoryIDs.insert(group.id)
                                        }
                                    }))
                                    .labelsHidden()
                            }
                        }
                    } else {
                        NavigationLink {
                            ChannelList(group: group, channels: channels, mode: mode)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.name)
                                Text("\(channels.count) channels").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle(title)
        .searchable(text: $filter, prompt: "Find a group")
        .task { await load() }
    }

    private func load() async {
        guard settings.xtream.isConfigured else {
            error = "Add your IPTV login in Settings › Connections first."
            loading = false
            return
        }
        let client = settings.xtreamClient
        do {
            let groups = try await XtreamCache.shared.liveCategories(client)
            let channels = try await XtreamCache.shared.liveStreams(client)
            var grouped: [String: [XtreamChannel]] = [:]
            for channel in channels {
                if let category = channel.categoryID { grouped[category, default: []].append(channel) }
            }
            categories = groups
            byGroup = grouped
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

/// One group's channels: switches to show or hide them, or ticks to put them in a folder.
private struct ChannelList: View {
    let group: XtreamCategory
    let channels: [XtreamChannel]
    let mode: ChannelBrowser.Mode
    @EnvironmentObject private var settings: AppSettings

    private var folderIndex: Int? {
        guard case .folder(let id) = mode else { return nil }
        return settings.prefs.folders.firstIndex { $0.id == id }
    }

    private var shown: [XtreamChannel] {
        mode == .visibility ? channels : channels.filter { !settings.prefs.hiddenChannelIDs.contains($0.id) }
    }

    var body: some View {
        List {
            if mode == .visibility {
                Section {
                    if settings.prefs.hiddenCategoryIDs.contains(group.id) {
                        Text("This whole group is hidden. Switch it back on in the list of groups.")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("Show all") { settings.prefs.hiddenChannelIDs.subtract(channels.map(\.id)) }
                            .buttonStyle(.glass)
                        Button("Hide all") { settings.prefs.hiddenChannelIDs.formUnion(channels.map(\.id)) }
                            .buttonStyle(.glass)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            Section {
                if shown.isEmpty {
                    Text("No channels in this group.").foregroundStyle(.secondary)
                }
                ForEach(shown) { channel in
                    if mode == .visibility {
                        let hidden = settings.prefs.hiddenChannelIDs.contains(channel.id)
                        Toggle(isOn: Binding(
                            get: { !hidden },
                            set: { on in
                                if on {
                                    settings.prefs.hiddenChannelIDs.remove(channel.id)
                                } else {
                                    settings.prefs.hiddenChannelIDs.insert(channel.id)
                                }
                            })) {
                            channelLabel(channel)
                        }
                    } else {
                        let included = folderIndex.map { settings.prefs.folders[$0].channelIDs.contains(channel.id) } ?? false
                        Button {
                            toggleInFolder(channel.id)
                        } label: {
                            HStack {
                                channelLabel(channel)
                                Spacer()
                                Image(systemName: included ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(included ? .white : .secondary)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(included ? .isSelected : [])
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle(group.name)
    }

    private func channelLabel(_ channel: XtreamChannel) -> some View {
        HStack(spacing: 12) {
            ChannelLogo(channel: channel, width: 48, height: 28)
            Text(channel.name).lineLimit(1)
        }
    }

    private func toggleInFolder(_ channelID: Int) {
        guard let index = folderIndex else { return }
        var folder = settings.prefs.folders[index]
        if let position = folder.channelIDs.firstIndex(of: channelID) {
            folder.channelIDs.remove(at: position)
        } else {
            folder.channelIDs.append(channelID)
        }
        settings.prefs.folders[index] = folder
    }
}

/// Your own Live TV folders.
struct FoldersSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var naming = false
    @State private var newName = ""

    var body: some View {
        List {
            Section {
                Button("New folder", systemImage: "plus") { naming = true }
            }
            if !settings.prefs.folders.isEmpty {
                Section {
                    ForEach(settings.prefs.folders) { folder in
                        NavigationLink {
                            FolderDetailView(folderID: folder.id)
                        } label: {
                            LabeledContent(folder.name, value: "\(folder.channelIDs.count) channels")
                        }
                    }
                    .onDelete { settings.prefs.folders.remove(atOffsets: $0) }
                    .onMove { settings.prefs.folders.move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    Text("Folders")
                }
            }
            Section {
            } footer: {
                Text("Folders are your own Live TV groups. A channel can be in several folders and stays in its original group too. Swipe left on a folder to delete it.")
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("My folders")
        .alert("New folder", isPresented: $naming) {
            TextField("Name", text: $newName)
            Button("Create") {
                let name = newName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    settings.prefs.folders.append(ChannelFolder(id: UUID().uuidString, name: name, channelIDs: []))
                }
                newName = ""
            }
            Button("Cancel", role: .cancel) { newName = "" }
        }
    }
}

/// A folder's channels in order: drag to reorder, swipe to remove; add more, rename or delete.
private struct FolderDetailView: View {
    let folderID: String
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var channels: [Int: XtreamChannel] = [:]
    @State private var renaming = false
    @State private var newName = ""
    @State private var confirmingDelete = false

    private var index: Int? { settings.prefs.folders.firstIndex { $0.id == folderID } }
    private var folder: ChannelFolder? { index.map { settings.prefs.folders[$0] } }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ChannelBrowser(mode: .folder(folderID))
                } label: {
                    Label("Add or remove channels", systemImage: "plus.circle")
                }
                Button("Rename", systemImage: "pencil") {
                    newName = folder?.name ?? ""
                    renaming = true
                }
                Button("Delete folder", systemImage: "trash", role: .destructive) { confirmingDelete = true }
            }
            if let folder, !folder.channelIDs.isEmpty {
                Section {
                    ForEach(folder.channelIDs, id: \.self) { id in
                        HStack(spacing: 12) {
                            if let channel = channels[id] {
                                ChannelLogo(channel: channel, width: 48, height: 28)
                            }
                            Text(channels[id]?.name ?? "Channel \(id)").lineLimit(1)
                        }
                    }
                    .onDelete { offsets in update { $0.channelIDs.remove(atOffsets: offsets) } }
                    .onMove { from, to in update { $0.channelIDs.move(fromOffsets: from, toOffset: to) } }
                } header: {
                    Text("Channels, in order")
                } footer: {
                    Text("Drag to reorder, swipe left to take a channel out.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle(folder?.name ?? "Folder")
        .toolbar { EditButton() }
        .task {
            guard settings.xtream.isConfigured else { return }
            let all = (try? await XtreamCache.shared.liveStreams(settings.xtreamClient)) ?? []
            channels = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        }
        .alert("Rename folder", isPresented: $renaming) {
            TextField("Name", text: $newName)
            Button("Save") {
                let name = newName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { update { $0.name = name } }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this folder?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete folder", role: .destructive) {
                settings.prefs.folders.removeAll { $0.id == folderID }
                dismiss()
            }
        } message: {
            Text("The channels stay in their original groups.")
        }
    }

    private func update(_ change: (inout ChannelFolder) -> Void) {
        guard let index else { return }
        var folder = settings.prefs.folders[index]
        change(&folder)
        settings.prefs.folders[index] = folder
    }
}

/// Choose which provider groups are split into 4K, FHD, HD and SD folders, with tidied names.
struct QualitySortSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var categories: [XtreamCategory] = []
    /// Per group: how many channels, and which quality folders it would get.
    @State private var summary: [String: (count: Int, qualities: [ChannelQuality])] = [:]
    @State private var loading = true
    @State private var error: String?

    /// The visible groups, with twins ("UK | Entertainment" and "… HEVC") as one row.
    private var rows: [(ids: [String], name: String)] {
        QualitySort.twinGroups(categories.filter { !settings.prefs.hiddenCategoryIDs.contains($0.id) })
    }

    var body: some View {
        SettingsPage("Sort by quality") {
            if loading {
                ProgressView().padding(40)
            } else if let error {
                SettingsNote(error)
            } else if rows.isEmpty {
                SettingsNote("Your IPTV account has no channel groups yet.")
            } else {
                SettingsGroup {
                    ForEach(rows, id: \.ids) { row in
                        SettingsToggleRow(title: row.name, subtitle: subtitle(for: row.ids, name: row.name),
                                          icon: "folder", isOn: binding(for: row.ids))
                    }
                }
            }
            SettingsNote("Pick the groups to split. Tellio sorts them again every time the channels load, so new channels land in the right folder. The original group is hidden; switch a group off to bring it back. Channel names in these groups lose the country tag at the start and HEVC, 4K, UHD, FHD, HD and SD; a name with no quality counts as SD.")
        }
        .task { await load() }
    }

    private func binding(for ids: [String]) -> Binding<Bool> {
        Binding(
            get: { ids.contains { settings.prefs.qualitySortCategoryIDs.contains($0) } },
            set: { on in
                if on {
                    settings.prefs.qualitySortCategoryIDs.formUnion(ids)
                } else {
                    settings.prefs.qualitySortCategoryIDs.subtract(ids)
                }
            })
    }

    /// "With … HEVC · 186 channels · FHD, HD and SD folders" when on, "64 channels" when off.
    private func subtitle(for ids: [String], name: String) -> String {
        let names = Dictionary(categories.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let count = ids.reduce(0) { $0 + (summary[$1]?.count ?? 0) }
        var parts: [String] = []
        let twins = ids.compactMap { names[$0] }.filter { $0.caseInsensitiveCompare(name) != .orderedSame }
        if ids.count > 1, !twins.isEmpty { parts.append("With " + twins.joined(separator: ", ")) }
        parts.append(count == 0 ? "No channels" : (count == 1 ? "1 channel" : "\(count) channels"))
        let present = Set(ids.flatMap { summary[$0]?.qualities ?? [] })
        let labels = ChannelQuality.allCases.filter { present.contains($0) }.map(\.label)
        if ids.contains(where: { settings.prefs.qualitySortCategoryIDs.contains($0) }), !labels.isEmpty {
            let list = labels.count == 1 ? labels[0]
                : labels.dropLast().joined(separator: ", ") + " and " + labels[labels.count - 1]
            parts.append("\(list) folder\(labels.count == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    private func load() async {
        guard settings.xtream.isConfigured else {
            error = "Add your IPTV login in Settings › Connections first."
            loading = false
            return
        }
        let client = settings.xtreamClient
        do {
            let groups = try await XtreamCache.shared.liveCategories(client)
            let channels = try await XtreamCache.shared.rawLiveStreams(client)
            let names = Dictionary(groups.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
            var tags: [String: String?] = [:]
            var counts: [String: Int] = [:]
            var found: [String: Set<ChannelQuality>] = [:]
            for channel in channels {
                guard let category = channel.categoryID,
                      !settings.prefs.hiddenChannelIDs.contains(channel.id) else { continue }
                counts[category, default: 0] += 1
                if tags[category] == nil { tags[category] = .some(QualitySort.countryTag(ofGroup: names[category] ?? "")) }
                found[category, default: []].insert(QualitySort.tidy(channel.name, groupTag: tags[category] ?? nil).quality)
            }
            categories = groups
            summary = counts.reduce(into: [:]) { result, entry in
                let present = found[entry.key] ?? []
                result[entry.key] = (entry.value, ChannelQuality.allCases.filter { present.contains($0) })
            }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
