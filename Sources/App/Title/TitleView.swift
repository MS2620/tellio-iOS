import SwiftUI

/// A film or series: artwork, details, overview, cast, My List and, for series, seasons and
/// episodes with watched ticks. Playing comes next (addon streams and resume).
struct TitleView: View {
    let item: TMDBItem
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var history = WatchHistory.shared

    @State private var details: TMDBDetails?
    @State private var season: Int?
    @State private var episodes: [TVEpisode] = []
    @State private var loadingEpisodes = false

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
                    Button {
                        settings.toggleMyList(item)
                    } label: {
                        Label(settings.isInMyList(item) ? "In My List" : "Add to My List",
                              systemImage: settings.isInMyList(item) ? "checkmark" : "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.white)
                    .foregroundStyle(Theme.ink)

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
                    EpisodeRow(item: item, episode: episode)
                }
            }
            .padding(.horizontal, 16)
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
