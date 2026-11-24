import SwiftUI

enum BrowseSection: String, CaseIterable, Identifiable {
    case movies = "Movies", series = "Series", calendar = "Calendar"
    var id: String { rawValue }
}

/// Browse: Movies, Series and the Calendar of new episodes, switched at the top.
/// The rows match the Apple TV's Movies and Series tabs.
struct BrowseView: View {
    @EnvironmentObject private var settings: AppSettings
    @SceneStorage("browse.section") private var section: BrowseSection = .movies

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Picker("Section", selection: $section) {
                        ForEach(BrowseSection.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)

                    if settings.tmdbToken.isEmpty && section != .calendar {
                        note("Add your TMDB token in Settings › Connections to browse films and series.")
                    }

                    switch section {
                    case .movies:
                        MyListRail(kind: .movie)
                        if settings.prefs.showProviderMovies { ProviderMoviesRail() }
                        ForEach(Catalog.movies) { CatalogRail(section: $0) }
                    case .series:
                        MyListRail(kind: .tv)
                        if settings.prefs.showProviderSeries { ProviderSeriesRail() }
                        ForEach(Catalog.series) { CatalogRail(section: $0) }
                    case .calendar:
                        CalendarList()
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .appBackground()
            .navigationTitle("Browse")
            .titleDestinations()
            .navigationDestination(for: XtreamSeries.self) { ProviderSeriesView(series: $0) }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text.localizedUI)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
    }
}

/// A poster-shaped tile for the provider's own library (artwork and name only).
private struct ProviderTile: View {
    let imageURL: URL?
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Artwork(url: imageURL, title: title)
                .frame(width: 112, height: 168)
                .clipShape(.rect(cornerRadius: 12))
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 112, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Recently added films from the IPTV provider's own library; tap to play.
struct ProviderMoviesRail: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var movies: [XtreamVOD] = []

    var body: some View {
        Group {
            if !movies.isEmpty {
                Rail(title: "From Your Provider · Recently Added") {
                    ForEach(movies) { movie in
                        Button {
                            play(movie)
                        } label: {
                            ProviderTile(imageURL: movie.icon.flatMap { URL(string: $0) }, title: movie.name)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .task(id: settings.xtream) {
            guard settings.xtream.isConfigured else { return }
            movies = (try? await XtreamCache.shared.recentMovies(settings.xtreamClient)) ?? []
        }
    }

    private func play(_ movie: XtreamVOD) {
        let client = settings.xtreamClient
        guard let url = client.movieURL(for: movie) else { return }
        SystemPlayer.present(PlaybackRequest(url: url, title: movie.name, httpHeaders: client.requestHeaders))
    }
}

/// Recently updated series from the IPTV provider's own library.
struct ProviderSeriesRail: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var series: [XtreamSeries] = []

    var body: some View {
        Group {
            if !series.isEmpty {
                Rail(title: "From Your Provider · Recently Updated") {
                    ForEach(series) { show in
                        NavigationLink(value: show) {
                            ProviderTile(imageURL: show.cover.flatMap { URL(string: $0) }, title: show.name)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .task(id: settings.xtream) {
            guard settings.xtream.isConfigured else { return }
            series = (try? await XtreamCache.shared.recentSeries(settings.xtreamClient)) ?? []
        }
    }
}

/// Seasons and episodes of a series from the provider's library.
struct ProviderSeriesView: View {
    let series: XtreamSeries
    @EnvironmentObject private var settings: AppSettings
    @State private var episodes: [XtreamEpisode] = []
    @State private var loading = true
    @State private var season: Int?

    private var seasons: [Int] { Array(Set(episodes.map(\.season))).sorted() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    Artwork(url: series.cover.flatMap { URL(string: $0) }, title: series.name)
                        .frame(width: 100, height: 150)
                        .clipShape(.rect(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SERIES · FROM YOUR PROVIDER")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.secondary)
                        Text(series.name)
                            .font(.title2.weight(.black))
                            .lineLimit(3)
                    }
                }
                if let plot = series.plot, !plot.isEmpty {
                    Text(plot).font(.subheadline).foregroundStyle(.secondary)
                }

                if loading {
                    ProgressView().frame(maxWidth: .infinity).padding()
                } else if episodes.isEmpty {
                    Text("No episodes found for this series.").foregroundStyle(.secondary)
                } else {
                    if seasons.count > 1 {
                        Picker("Season", selection: $season) {
                            ForEach(seasons, id: \.self) { Text("Season \($0)").tag(Optional($0)) }
                        }
                        .pickerStyle(.menu)
                        .tint(.white)
                    }
                    LazyVStack(spacing: 10) {
                        ForEach(episodes.filter { $0.season == season }) { episode in
                            Button {
                                play(episode)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(verbatim: "\(episode.number). \(episode.title)")
                                            .font(.subheadline.weight(.bold))
                                            .lineLimit(2)
                                        if let plot = episode.plot, !plot.isEmpty {
                                            Text(plot)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer(minLength: 8)
                                    Image(systemName: "play.fill").foregroundStyle(.secondary)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassPanel(cornerRadius: 16)
                                .contentShape(.rect(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .appBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task {
            episodes = (try? await settings.xtreamClient.seriesEpisodes(seriesID: series.id)) ?? []
            season = seasons.first
            loading = false
        }
    }

    private func play(_ episode: XtreamEpisode) {
        let client = settings.xtreamClient
        guard let url = client.episodeURL(for: episode) else { return }
        SystemPlayer.present(PlaybackRequest(url: url, title: series.name,
                                             subtitle: "S\(episode.season)E\(episode.number) · \(episode.title)",
                                             httpHeaders: client.requestHeaders))
    }
}
