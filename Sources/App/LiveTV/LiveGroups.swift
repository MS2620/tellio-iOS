import Foundation

/// A Live TV group: Favourites, Recent, one of your folders, a provider group, or a quality
/// folder of a group sorted by quality. Same ids and rules as the Apple TV app.
struct LiveGroup: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    var locked = false

    static let favouritesID = "__favourites"
    static let recentID = "__recent"
    static let folderPrefix = "folder:"

    var isFavourites: Bool { id == Self.favouritesID }
    var isRecent: Bool { id == Self.recentID }
    var isFolder: Bool { id.hasPrefix(Self.folderPrefix) }
    /// Groups that mix channels from several provider groups, and keep the order you gave them.
    var isMixed: Bool { isFavourites || isRecent || isFolder }
}

@MainActor
enum LiveGroups {
    /// Recent, Favourites, your folders, then the provider's groups that aren't hidden.
    static func list(categories: [XtreamCategory], qualityFolders: [String: [ChannelQuality]],
                     prefs: Preferences, parental: ParentalLock) -> [LiveGroup] {
        var list = prefs.folders.map {
            LiveGroup(id: LiveGroup.folderPrefix + $0.id, name: $0.name, icon: "square.stack.3d.up")
        }
        let merged = QualitySort.mergedGroups(categories, chosen: prefs.qualitySortCategoryIDs)
        var shownLeads = Set<String>()
        for category in categories {
            if let group = merged[category.id] {
                // Sorted by quality: its 4K, FHD, HD and SD folders take its place.
                guard shownLeads.insert(group.lead).inserted else { continue }
                let twins = merged.filter { $0.value.lead == group.lead }.map(\.key)
                if twins.allSatisfy({ prefs.hiddenCategoryIDs.contains($0) }) { continue }
                let locked = isLocked(groupID: group.lead, categories: categories, prefs: prefs, parental: parental)
                if prefs.hideLockedGroups && locked { continue }
                for quality in qualityFolders[group.lead] ?? [] {
                    list.append(LiveGroup(id: QualitySort.folderID(category: group.lead, quality: quality),
                                          name: "\(group.name) \(quality.label)", icon: "folder", locked: locked))
                }
                continue
            }
            if prefs.hiddenCategoryIDs.contains(category.id) { continue }
            let locked = parental.isLocked(categoryID: category.id, prefs: prefs)
            if prefs.hideLockedGroups && locked { continue }
            list.append(LiveGroup(id: category.id, name: category.name, icon: "folder", locked: locked))
        }
        if !prefs.favouriteChannelIDs.isEmpty {
            let favourites = LiveGroup(id: LiveGroup.favouritesID, name: String(localized: "Favourites"), icon: "star")
            if prefs.favouritesFirst { list.insert(favourites, at: 0) } else { list.append(favourites) }
        }
        if !prefs.recentChannelIDs.isEmpty {
            list.insert(LiveGroup(id: LiveGroup.recentID, name: String(localized: "Recent"), icon: "clock.arrow.circlepath"), at: 0)
        }
        return list
    }

    /// A group or quality folder is locked when it, or any group merged with it, is.
    static func isLocked(groupID id: String, categories: [XtreamCategory], prefs: Preferences,
                         parental: ParentalLock) -> Bool {
        let lead = QualitySort.baseCategory(of: id)
        let merged = QualitySort.mergedGroups(categories, chosen: prefs.qualitySortCategoryIDs)
        guard merged[lead] != nil else { return parental.isLocked(categoryID: lead, prefs: prefs) }
        return merged.contains { $0.value.lead == lead && parental.isLocked(categoryID: $0.key, prefs: prefs) }
    }

    /// Which quality folders the groups sorted by quality need (only ones with channels show).
    static func qualityFolders(settings: AppSettings) async -> [String: [ChannelQuality]] {
        guard !settings.prefs.qualitySortCategoryIDs.isEmpty, settings.xtream.isConfigured else { return [:] }
        let all = (try? await XtreamCache.shared.liveStreams(settings.xtreamClient)) ?? []
        var found: [String: Set<ChannelQuality>] = [:]
        for channel in all {
            guard let lead = channel.folderGroupID, let quality = channel.quality, settings.isVisible(channel) else { continue }
            found[lead, default: []].insert(quality)
        }
        return found.mapValues { present in ChannelQuality.allCases.filter { present.contains($0) } }
    }

    /// The channels of a group, as the Apple TV app loads them.
    static func channels(in group: LiveGroup, settings: AppSettings, parental: ParentalLock) async -> [XtreamChannel] {
        let client = settings.xtreamClient
        let prefs = settings.prefs
        func all() async -> [XtreamChannel] { (try? await XtreamCache.shared.liveStreams(client)) ?? [] }
        func byID(_ list: [XtreamChannel]) -> [Int: XtreamChannel] {
            Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        }

        if group.isRecent {
            let lookup = byID(await all())
            return prefs.recentChannelIDs.compactMap { lookup[$0] }.filter { channel in
                settings.isVisible(channel) && !parental.isLocked(categoryID: channel.categoryID ?? "", prefs: prefs)
            }
        }
        if group.isFavourites {
            return await all().filter { prefs.favouriteChannelIDs.contains($0.id) && settings.isVisible($0) }
        }
        if group.isFolder {
            let folderID = String(group.id.dropFirst(LiveGroup.folderPrefix.count))
            let ids = prefs.folders.first { $0.id == folderID }?.channelIDs ?? []
            let lookup = byID(await all())
            return ids.compactMap { lookup[$0] }
        }
        if let folder = QualitySort.parseFolderID(group.id) {
            return await all().filter {
                $0.folderGroupID == folder.category && $0.quality == folder.quality && settings.isVisible($0)
            }
        }
        let list = (try? await client.liveStreams(categoryID: group.id)) ?? []
        return QualitySort.applyCustomNames(list.filter { !prefs.hiddenChannelIDs.contains($0.id) })
    }

    static func sorted(_ channels: [XtreamChannel], in group: LiveGroup?, by sort: ChannelSort) -> [XtreamChannel] {
        if group?.isMixed == true { return channels }
        switch sort {
        case .server: return channels
        case .number: return channels.sorted { ($0.number ?? .max) < ($1.number ?? .max) }
        case .name: return channels.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
}

/// What's on now and next, from a channel's listings.
enum NowNext {
    static func current(_ entries: [XtreamEPGEntry]?, at now: Date) -> XtreamEPGEntry? {
        entries?.first { ($0.start ?? .distantFuture) <= now && now < ($0.end ?? .distantPast) }
    }

    static func next(_ entries: [XtreamEPGEntry]?, at now: Date) -> XtreamEPGEntry? {
        guard let ends = current(entries, at: now)?.end else { return nil }
        return entries?
            .filter { ($0.start ?? .distantPast) >= ends }
            .min { ($0.start ?? .distantPast) < ($1.start ?? .distantPast) }
    }

    static func progress(_ entry: XtreamEPGEntry, at now: Date) -> Double {
        guard let start = entry.start, let end = entry.end, end > start else { return 0 }
        return min(1, max(0, now.timeIntervalSince(start) / end.timeIntervalSince(start)))
    }

    /// Listings from an hour ago to a day ahead, for several channels, a few at a time.
    static func load(_ ids: [Int], client: XtreamClient,
                     into update: @escaping @MainActor ([Int: [XtreamEPGEntry]]) -> Void) async {
        guard !ids.isEmpty else { return }
        let from = Date().addingTimeInterval(-3600)
        let until = Date().addingTimeInterval(24 * 3600)
        var queue = ids.makeIterator()
        var buffer: [Int: [XtreamEPGEntry]] = [:]

        @Sendable func listings(_ id: Int) async -> (Int, [XtreamEPGEntry]) {
            let all = await XtreamCache.shared.guide(client, streamID: id)
            return (id, all.filter { entry in
                guard let begins = entry.start, let ends = entry.end else { return false }
                return ends > from && begins < until
            })
        }

        await withTaskGroup(of: (Int, [XtreamEPGEntry]).self) { group in
            for _ in 0..<6 {
                guard let id = queue.next() else { break }
                group.addTask { await listings(id) }
            }
            while let (id, entries) = await group.next() {
                if Task.isCancelled {
                    group.cancelAll()
                    break
                }
                buffer[id] = entries
                if buffer.count >= 4 {
                    await update(buffer)
                    buffer.removeAll()
                }
                if let nextID = queue.next() { group.addTask { await listings(nextID) } }
            }
        }
        if !buffer.isEmpty { await update(buffer) }
    }
}
