import SwiftUI

/// New episodes of the series in My List, day by day: today first, then what's coming up
/// (how many per series and how far ahead follow the Apple TV's Calendar settings).
/// Nothing that has already aired.
struct CalendarList: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var entries: [Entry] = []
    @State private var loading = false

    struct Entry: Identifiable, Hashable {
        let show: TMDBItem
        let episode: TVEpisode
        let date: Date
        var id: String { "\(show.id)-\(episode.id)" }
    }

    private var series: [TMDBItem] {
        settings.prefs.myList.filter { $0.kind == .tv }
    }

    private var loadKey: String {
        series.map { String($0.id) }.joined(separator: ",")
            + "|\(settings.tmdbToken.count)|\(settings.prefs.calendarEpisodesPerSeries)|\(settings.prefs.calendarDaysAhead)"
    }

    private var days: [(date: Date, entries: [Entry])] {
        Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.date) }
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if settings.tmdbToken.isEmpty {
                note("Add your TMDB token in Settings › Connections to see release dates.")
            } else if series.isEmpty {
                note("Add series to My List to see when their new episodes come out.")
            } else if loading && entries.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
            } else if entries.isEmpty {
                note("No new episodes coming up for the series in My List.")
            }

            ForEach(days, id: \.date) { day in
                VStack(alignment: .leading, spacing: 10) {
                    Text(Self.heading(day.date))
                        .font(.title3.weight(.heavy))
                        .accessibilityAddTraits(.isHeader)
                    ForEach(day.entries) { entry in
                        NavigationLink(value: entry.show) {
                            CalendarRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .task(id: loadKey) { await load() }
    }

    private func note(_ text: String) -> some View {
        Text(text.localizedUI)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
    }

    /// "Today", "Tomorrow", or "Thursday 27 November".
    private static func heading(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    // MARK: - Loading (as on the Apple TV)

    private func load() async {
        guard !settings.tmdbToken.isEmpty, !series.isEmpty else {
            entries = []
            return
        }
        loading = true
        defer { loading = false }

        let tmdb = settings.tmdb
        let perSeries = max(1, settings.prefs.calendarEpisodesPerSeries)
        let today = Calendar.current.startOfDay(for: Date())
        let until = Calendar.current.date(byAdding: .day, value: settings.prefs.calendarDaysAhead, to: today) ?? today

        var found: [Entry] = []
        await withTaskGroup(of: [Entry].self) { group in
            for show in series {
                group.addTask {
                    await Self.entries(for: show, tmdb: tmdb, from: today, until: until, limit: perSeries)
                }
            }
            for await list in group { found += list }
        }
        entries = found.sorted { a, b in
            a.date != b.date ? a.date < b.date : a.show.displayTitle < b.show.displayTitle
        }
    }

    /// The next `limit` episodes of one series airing from today onwards.
    private static func entries(for show: TMDBItem, tmdb: TMDBClient,
                                from: Date, until: Date, limit: Int) async -> [Entry] {
        guard let details = try? await tmdb.tvDetails(id: show.id) else { return [] }

        // TMDB moves today's episode to "last aired" on the day, so check both.
        var seasons = Set<Int>()
        if let next = details.nextEpisodeToAir { seasons.insert(next.seasonNumber) }
        if let last = details.lastEpisodeToAir, let aired = DayFormat.parseDay(last.airDate), aired >= from {
            seasons.insert(last.seasonNumber)
        }
        guard !seasons.isEmpty else { return [] }

        var result: [Entry] = []
        for season in seasons.sorted() {
            let episodes = (try? await tmdb.episodes(tvID: show.id, season: season)) ?? []
            for episode in episodes {
                if let date = DayFormat.parseDay(episode.airDate), date >= from, date <= until {
                    result.append(Entry(show: show, episode: episode, date: date))
                }
            }
        }
        // If the season list had no dates, fall back to the next episode itself.
        if result.isEmpty, let next = details.nextEpisodeToAir,
           let date = DayFormat.parseDay(next.airDate), date >= from, date <= until {
            result.append(Entry(show: show, episode: next, date: date))
        }
        return Array(result.sorted { $0.date < $1.date }.prefix(limit))
    }
}

/// A series' episode on a calendar day: still (or poster), series, episode number and name.
private struct CalendarRow: View {
    let entry: CalendarList.Entry

    var body: some View {
        HStack(spacing: 12) {
            Artwork(url: entry.episode.stillURL ?? entry.show.backdropURL, title: entry.show.displayTitle)
                .frame(width: 112, height: 63)
                .clipShape(.rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.show.displayTitle)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                Text(verbatim: "S\(entry.episode.seasonNumber) · E\(entry.episode.episodeNumber)"
                     + (entry.episode.name.map { " · \($0)" } ?? ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .glassPanel(cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }
}
