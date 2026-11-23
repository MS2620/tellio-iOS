import SwiftUI

/// A film or series: artwork, details, overview, cast, My List and, for series, seasons and
/// episodes with watched ticks. Play and the episodes open the stream page.
struct TitleView: View {
    let item: TMDBItem
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var history = WatchHistory.shared

    @State private var details: TMDBDetails?
    @State private var season: Int?
    @State private var episodes: [TVEpisode] = []
    @State private var loadingEpisodes = false

    private var imdbID: String? { details?.externalIds?.imdbId }

    /// Play (or resume) for a film; for a series, the episode you're part-way through, else
    /// the first episode.
    private var playTarget: (target: StreamTarget, label: String)? {
        guard let imdbID else { return nil }
        if item.kind == .movie {
            let entry = history.entry(item: item)
            return (.movie(item: item, imdbID: imdbID),
                    entry?.isResumable == true ? "Resume · \(entry!.timeLeftLabel)" : "Play")
        }
        if let latest = history.latestEpisode(of: item), latest.isResumable,
           let season = latest.context.season, let episode = latest.context.episode {
            return (.episode(item: item, imdbID: imdbID, season: season, episode: episode,
                             name: latest.context.episodeName),
                    "Resume S\(season) · E\(episode)")
        }
        guard let first = seasons.first else { return nil }
        return (.episode(item: item, imdbID: imdbID, season: first.seasonNumber, episode: 1, name: nil),
                "Play S\(first.seasonNumber) · E1")
    }

    private var seasons: [TVSeasonSummary] {
        (details?.seasons ?? []).filter { $0.seasonNumber > 0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                backdrop
                VStack(alignment: .leading, spacing: 14) {
                    Text(item.displayTitle)
                        .font(.largeTitle.weight(.black))
                        .lineLimit(3)
                    if !chips.isEmpty {
                        Text(chips.joined(separator: " · "))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 10) {
                        if let play = playTarget {
                            NavigationLink(value: play.target) {
                                Label(play.label, systemImage: "play.fill")
                                    .font(.headline)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, minHeight: 30)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(.white)
                            .foregroundStyle(Theme.ink)
                        } else if details != nil && imdbID == nil {
                            Text("Can't be played: this title has no IMDb id for addons to look up.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ProgressView().frame(maxWidth: .infinity, minHeight: 30)
                        }
                        Button {
                            settings.toggleMyList(item)
                        } label: {
                            Image(systemName: settings.isInMyList(item) ? "checkmark" : "plus")
                                .font(.headline)
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.glass)
                        .accessibilityLabel(settings.isInMyList(item) ? "Remove from My List" : "Add to My List")
                    }

                    if let tagline = details?.tagline, !tagline.isEmpty {
                        Text(tagline).font(.headline).italic()
                    }
                    if let overview = item.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    if let cast = castLine {
                        Text(cast)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)

                if item.kind == .tv, !seasons.isEmpty {
                    seasonSection
                }

                if let more = details?.recommendations?.results, !more.isEmpty {
                    Rail(title: "More like this") {
                        ForEach(more.prefix(20), id: \.uid) { other in
                            NavigationLink(value: other) { PosterCard(item: other) }
                                .buttonStyle(.plain)
                                .contextMenu { TitleMenu(item: other) }
                        }
                    }
                }
            }
            .padding(.bottom, 32)
        }
        .ignoresSafeArea(edges: .top)
        .appBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task(id: item.uid) { await load() }
        .task(id: season) { await loadEpisodes() }
    }

    private var backdrop: some View {
        Artwork(url: item.backdropURL ?? item.posterURL)
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .clipped()
            .overlay {
                LinearGradient(colors: [.clear, Theme.base.opacity(0.85)], startPoint: .center, endPoint: .bottom)
            }
            .accessibilityHidden(true)
    }

    /// "2024 · Drama, Crime · ★ 8.1 · 2h 4m" or "2019 · 3 seasons".
    private var chips: [String] {
        var parts: [String] = []
        if let year = item.year { parts.append(year) }
        let genres = details?.genres?.prefix(2).map(\.name) ?? item.genreNames
        if !genres.isEmpty { parts.append(genres.joined(separator: ", ")) }
        if let rating = item.rating { parts.append("★ \(rating)") }
        if let runtime = details?.runtime, runtime > 0 {
            parts.append(runtime >= 60 ? "\(runtime / 60)h \(runtime % 60)m" : "\(runtime)m")
        }
        if let count = details?.numberOfSeasons {
            parts.append(count == 1 ? "1 season" : "\(count) seasons")
        }
        return parts
    }

    private var castLine: String? {
        guard let cast = details?.credits?.cast, !cast.isEmpty else { return nil }
        return "Starring " + cast.prefix(4).map(\.name).joined(separator: ", ")
    }

    private var seasonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Episodes").font(.title3.weight(.heavy))
                Spacer()
                Menu {
                    ForEach(seasons, id: \.seasonNumber) { summary in
                        Button(summary.name ?? "Season \(summary.seasonNumber)") { season = summary.seasonNumber }
                    }
                } label: {
                    Label(seasons.first { $0.seasonNumber == season }?.name ?? "Season \(season ?? 1)",
                          systemImage: "chevron.up.chevron.down")
                        .font(.subheadline.weight(.bold))
                }
                .buttonStyle(.glass)
            }
            .padding(.horizontal, 20)

            if loadingEpisodes && episodes.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding()
            }
            LazyVStack(spacing: 10) {
                ForEach(episodes, id: \.id) { episode in
                    if let imdbID {
                        NavigationLink(value: StreamTarget.episode(item: item, imdbID: imdbID,
                                                                   season: episode.seasonNumber,
                                                                   episode: episode.episodeNumber,
                                                                   name: episode.name)) {
                            EpisodeRow(item: item, episode: episode)
                        }
                        .buttonStyle(.plain)
                        .contextMenu { episodeMenu(episode, imdbID: imdbID) }
                    } else {
                        EpisodeRow(item: item, episode: episode)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func episodeMenu(_ episode: TVEpisode, imdbID: String) -> some View {
        let context = WatchContext(item: item, imdbID: imdbID, season: episode.seasonNumber,
                                   episode: episode.episodeNumber, episodeName: episode.name)
        let watched = history.isWatched(item, season: episode.seasonNumber, episode: episode.episodeNumber)
        Button(watched ? "Mark as unwatched" : "Mark as watched",
               systemImage: watched ? "eye.slash" : "checkmark.circle") {
            history.setWatched(!watched, context: context)
        }
    }

    private func load() async {
        guard !settings.tmdbToken.isEmpty else { return }
        details = try? await settings.tmdb.details(for: item)
        if item.kind == .tv, season == nil {
            // Opens on the season you're watching, else the first.
            season = history.latestEpisode(of: item)?.context.season ?? seasons.first?.seasonNumber
        }
    }

    private func loadEpisodes() async {
        guard item.kind == .tv, let season else { return }
        loadingEpisodes = true
        defer { loadingEpisodes = false }
        episodes = (try? await settings.tmdb.episodes(tvID: item.id, season: season)) ?? []
    }
}

/// An episode: still, number and name, air date or runtime, overview, watched tick or progress.
private struct EpisodeRow: View {
    let item: TMDBItem
    let episode: TVEpisode
    @ObservedObject private var history = WatchHistory.shared

    private var entry: WatchEntry? {
        history.entry(item: item, season: episode.seasonNumber, episode: episode.episodeNumber)
    }

    private var watched: Bool {
        history.isWatched(item, season: episode.seasonNumber, episode: episode.episodeNumber)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Artwork(url: episode.stillURL)
                .frame(width: 128, height: 72)
                .clipShape(.rect(cornerRadius: 10))
                .overlay(alignment: .bottom) {
                    if let entry, entry.isResumable {
                        ProgressView(value: entry.fraction).tint(.white).padding(6)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if watched {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Theme.ink, .white)
                            .padding(5)
                            .accessibilityLabel("Watched")
                    }
                }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(episode.episodeNumber). \(episode.name ?? "Episode \(episode.episodeNumber)")")
                    .font(.subheadline.weight(.bold))
                    .lineLimit(2)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let overview = episode.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .glassPanel(cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        var parts: [String] = []
        if let air = DayFormat.parseDay(episode.airDate) {
            parts.append(air > Date() ? "Airs " + air.formatted(date: .abbreviated, time: .omitted)
                                      : air.formatted(date: .abbreviated, time: .omitted))
        }
        if let runtime = episode.runtime, runtime > 0 { parts.append("\(runtime)m") }
        return parts.joined(separator: " · ")
    }
}
