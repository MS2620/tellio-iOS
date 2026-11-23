import SwiftUI

/// A catalogue row that loads its titles from TMDB the first time it appears.
struct CatalogRail: View {
    let section: CatalogSection
    @EnvironmentObject private var settings: AppSettings
    @State private var items: [TMDBItem] = []
    @State private var failed = false

    var body: some View {
        Group {
            if items.isEmpty {
                // Keeps the row's place so it can load when scrolled to.
                Color.clear.frame(height: failed ? 0 : 1)
            } else {
                Rail(title: section.id) {
                    ForEach(items, id: \.uid) { item in
                        NavigationLink(value: item) {
                            switch section.style {
                            case .poster: PosterCard(item: item)
                            case .landscape: BackdropCard(item: item)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu { TitleMenu(item: item) }
                    }
                }
            }
        }
        .task(id: "\(settings.tmdbToken.count)|\(settings.prefs.tmdbLanguage)|\(settings.prefs.tmdbRegion)") {
            guard !settings.tmdbToken.isEmpty else { return }
            do {
                items = try await section.fetch(settings.tmdb)
            } catch {
                failed = true
            }
        }
    }
}

/// My List, newest first; films only, series only, or both.
struct MyListRail: View {
    var kind: MediaType? = nil
    @EnvironmentObject private var settings: AppSettings

    private var items: [TMDBItem] {
        settings.prefs.myList.reversed().filter { kind == nil || $0.kind == kind }
    }

    var body: some View {
        if !items.isEmpty {
            Rail(title: "My List") {
                ForEach(items, id: \.uid) { item in
                    NavigationLink(value: item) { PosterCard(item: item) }
                        .buttonStyle(.plain)
                        .contextMenu { TitleMenu(item: item) }
                }
            }
        }
    }
}

/// Continue Watching: titles part-watched, and the next episode of series you finished one of.
struct ContinueWatchingRail: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var history = WatchHistory.shared
    @State private var nextEpisodes: [String: NextEpisode] = [:]

    struct NextEpisode: Hashable {
        let season: Int
        let episode: Int
        let name: String?
        let stillURL: URL?
        let isNew: Bool
    }

    struct Card: Identifiable {
        let id: String
        let entry: WatchEntry
        let line: String
        let fraction: Double?
        let badge: String?
        let imageURL: URL?
    }

    /// Same rules as the Apple TV's Continue Watching row.
    var cards: [Card] {
        history.latestPerTitle.prefix(30).compactMap { entry -> Card? in
            let item = entry.item
            guard !entry.context.imdbID.isEmpty else { return nil }
            if entry.isResumable {
                let line = [entry.episodeLabel, entry.timeLeftLabel].compactMap { $0 }.joined(separator: " · ")
                return Card(id: entry.id, entry: entry, line: line, fraction: entry.fraction, badge: nil,
                            imageURL: item.backdropURL)
            }
            // A finished episode: offer the next one, once it has aired.
            guard entry.watched, entry.context.season != nil, !history.dismissedNextUp.contains(item.uid),
                  let next = nextEpisodes[entry.id] else { return nil }
            return Card(id: "next-\(item.uid)", entry: entry, line: "Next: S\(next.season) · E\(next.episode)",
                        fraction: nil, badge: next.isNew ? "NEW EPISODE" : "UP NEXT",
                        imageURL: next.stillURL ?? item.backdropURL)
        }
        .prefix(20)
        .map { $0 }
    }

    private var finishedKey: String {
        history.latestPerTitle.prefix(30).filter { $0.watched && $0.context.season != nil }.map(\.id)
            .joined(separator: ",")
    }

    var body: some View {
        let list = cards
        Group {
            if !list.isEmpty {
                Rail(title: "Continue Watching") {
                    ForEach(list) { card in
                        NavigationLink(value: card.entry.item) {
                            ContinueCard(card: card)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if card.fraction != nil {
                                Button("Mark as watched", systemImage: "checkmark.circle") {
                                    history.setWatched(true, context: card.entry.context)
                                }
                            }
                            Button("Remove from Continue Watching", systemImage: "xmark.circle", role: .destructive) {
                                history.remove(card.entry.item)
                            }
                        }
                    }
                }
            }
        }
        .task(id: finishedKey) { await loadNextEpisodes() }
    }

    /// Looks up the episode after each finished one: the rest of its season, then the next season's first.
    private func loadNextEpisodes() async {
        let finished = history.latestPerTitle.prefix(30).filter { $0.watched && $0.context.season != nil }
        guard !finished.isEmpty, !settings.tmdbToken.isEmpty else { return }
        let tmdb = settings.tmdb
        let today = Self.day(Date())
        let fortnightAgo = Self.day(Date().addingTimeInterval(-14 * 86_400))
        var found: [String: NextEpisode] = [:]
        for entry in finished.prefix(12) {
            guard let season = entry.context.season, let episode = entry.context.episode else { continue }
            let thisSeason = (try? await tmdb.episodes(tvID: entry.item.id, season: season)) ?? []
            var upcoming = thisSeason.first { $0.episodeNumber == episode + 1 }
            if upcoming == nil {
                let nextSeason = (try? await tmdb.episodes(tvID: entry.item.id, season: season + 1)) ?? []
                upcoming = nextSeason.first { $0.episodeNumber == 1 }
            }
            guard let next = upcoming, let aired = next.airDate, !aired.isEmpty, aired <= today else { continue }
            found[entry.id] = NextEpisode(season: next.seasonNumber, episode: next.episodeNumber, name: next.name,
                                          stillURL: next.stillURL, isNew: aired >= fortnightAgo)
        }
        nextEpisodes = found
    }

    private static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private struct ContinueCard: View {
    let card: ContinueWatchingRail.Card

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Artwork(url: card.imageURL, title: card.entry.item.displayTitle)
                .frame(width: 210, height: 118)
                .clipShape(.rect(cornerRadius: 12))
                .overlay(alignment: .bottom) {
                    if let fraction = card.fraction {
                        ProgressView(value: fraction)
                            .tint(.white)
                            .padding(10)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if let badge = card.badge {
                        Text(badge)
                            .font(.caption2.weight(.heavy))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.6), in: .capsule)
                            .padding(8)
                    }
                }
            Text(card.entry.item.displayTitle)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .frame(width: 210, alignment: .leading)
            Text(card.line)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 210, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Your favourite channels with what's on now; tap to watch.
struct FavouriteChannelsRail: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var channels: [XtreamChannel] = []
    @State private var epg: [Int: [XtreamEPGEntry]] = [:]

    var body: some View {
        Group {
            if !channels.isEmpty {
                Rail(title: "Favourite Channels") {
                    ForEach(channels) { channel in
                        let current = NowNext.current(epg[channel.id], at: Date())
                        Button {
                            ChannelPlayback.play(channel, in: channels, settings: settings, nowPlaying: current?.title)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                ChannelLogo(channel: channel, width: 140, height: 80)
                                Text(channel.name).font(.subheadline.weight(.bold)).lineLimit(1)
                                Text(current?.title ?? " ")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 140, alignment: .leading)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .task(id: "\(settings.xtream.id)|\(settings.prefs.favouriteChannelIDs.count)") {
            guard settings.xtream.isConfigured, !settings.prefs.favouriteChannelIDs.isEmpty else {
                channels = []
                return
            }
            let all = (try? await XtreamCache.shared.liveStreams(settings.xtreamClient)) ?? []
            channels = all.filter { settings.prefs.favouriteChannelIDs.contains($0.id) && settings.isVisible($0) }
            await NowNext.load(channels.prefix(30).map(\.id), client: settings.xtreamClient) { batch in
                epg.merge(batch) { _, new in new }
            }
        }
    }
}
