import Foundation

// The catalogue rows, as on the Apple TV (its Catalog lives in a tvOS view file, so it's
// repeated here; keep the two in step).

enum RailStyle { case poster, landscape }

/// One titled row of TMDB titles, fetched when it first appears.
struct CatalogSection: Identifiable {
    let id: String
    var style: RailStyle = .poster
    let fetch: @Sendable (TMDBClient) async throws -> [TMDBItem]
}

enum Catalog {
    /// The TMDB-backed Home rows (My List, channels and teams are built separately).
    static func homeSection(_ row: HomeRow) -> CatalogSection? {
        switch row {
        case .trending:
            return CatalogSection(id: row.title, style: .landscape) { try await $0.trendingAll() }
        case .popularMovies:
            return CatalogSection(id: row.title) { try await $0.popular(.movie) }
        case .popularSeries:
            return CatalogSection(id: row.title) { try await $0.popular(.tv) }
        case .cinemas:
            return CatalogSection(id: row.title, style: .landscape) { try await $0.list("movie/now_playing", type: .movie) }
        case .airingToday:
            return CatalogSection(id: row.title) { try await $0.list("tv/airing_today", type: .tv) }
        case .topRated:
            return CatalogSection(id: row.title) { try await $0.list("movie/top_rated", type: .movie) }
        case .myList, .channels, .teams:
            return nil
        }
    }

    private static let movieGenres: [(String, Int)] = [
        ("Action", 28), ("Comedy", 35), ("Thriller", 53), ("Horror", 27),
        ("Science Fiction", 878), ("Drama", 18), ("Animation", 16), ("Family", 10751),
        ("Crime", 80), ("Romance", 10749), ("Documentary", 99),
    ]

    private static let seriesGenres: [(String, Int)] = [
        ("Drama", 18), ("Comedy", 35), ("Crime", 80), ("Action & Adventure", 10759),
        ("Sci-Fi & Fantasy", 10765), ("Mystery", 9648), ("Animation", 16),
        ("Documentary", 99), ("Reality", 10764), ("Kids", 10762),
    ]

    static let movies: [CatalogSection] = [
        CatalogSection(id: "Trending", style: .landscape) { try await $0.trending(.movie) },
        CatalogSection(id: "Popular") { try await $0.popular(.movie) },
        CatalogSection(id: "Now Playing", style: .landscape) { try await $0.list("movie/now_playing", type: .movie) },
        CatalogSection(id: "Upcoming") { try await $0.list("movie/upcoming", type: .movie) },
        CatalogSection(id: "Top Rated") { try await $0.list("movie/top_rated", type: .movie) },
    ] + movieGenres.map { name, id in
        CatalogSection(id: name) { try await $0.discover(.movie, genre: id) }
    }

    static let series: [CatalogSection] = [
        CatalogSection(id: "Trending", style: .landscape) { try await $0.trending(.tv) },
        CatalogSection(id: "Popular") { try await $0.popular(.tv) },
        CatalogSection(id: "Airing Today", style: .landscape) { try await $0.list("tv/airing_today", type: .tv) },
        CatalogSection(id: "On The Air") { try await $0.list("tv/on_the_air", type: .tv) },
        CatalogSection(id: "Top Rated") { try await $0.list("tv/top_rated", type: .tv) },
    ] + seriesGenres.map { name, id in
        CatalogSection(id: name) { try await $0.discover(.tv, genre: id) }
    }
}

extension AppSettings {
    func isInMyList(_ item: TMDBItem) -> Bool {
        prefs.myList.contains { $0.uid == item.uid }
    }

    /// Adds or removes a title (Trakt's watchlist follows when that sync is on).
    func toggleMyList(_ item: TMDBItem) {
        if isInMyList(item) {
            prefs.myList.removeAll { $0.uid == item.uid }
        } else {
            prefs.myList.append(item)
        }
    }
}
