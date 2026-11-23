import SwiftUI

/// Home: the Tellio header and Settings gear, a hero card, then the rows in the order set in
/// Settings › Home screen (shared with the Apple TV).
struct HomeView: View {
    let showSettings: () -> Void
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var history = WatchHistory.shared
    @State private var trending: TMDBItem?

    /// What you were last watching, else the first title of My List, else what's trending.
    private var hero: (item: TMDBItem, kicker: String)? {
        if let entry = history.latestPerTitle.first(where: \.isResumable) {
            return (entry.item, "CONTINUE WATCHING")
        }
        if settings.visibleHomeRows.contains(.myList), let first = settings.prefs.myList.last {
            return (first, "MY LIST")
        }
        if let trending {
            return (trending, "TRENDING · " + (trending.kind == .movie ? "FILM" : "SERIES"))
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if let hero {
                        HeroCard(item: hero.item, kicker: hero.kicker)
                            .padding(.horizontal, 20)
                    }
                    if settings.tmdbToken.isEmpty && !settings.xtream.isConfigured {
                        gettingStarted
                    }
                    ContinueWatchingRail()
                    ForEach(settings.visibleHomeRows) { row in
                        homeRow(row)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .appBackground()
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: TMDBItem.self) { item in
                TitleView(item: item)
            }
        }
        .task(id: settings.tmdbToken.count) {
            guard trending == nil, !settings.tmdbToken.isEmpty else { return }
            trending = try? await settings.tmdb.trendingAll().first { $0.backdropPath != nil }
        }
    }

    private var header: some View {
        HStack {
            Text("Tellio").font(.title.weight(.black))
            Spacer()
            GlassIconButton("gearshape", label: "Settings", action: showSettings)
        }
        .padding(.horizontal, 20)
    }

    private var gettingStarted: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Welcome to Tellio").font(.headline.weight(.heavy))
            Text("Bring your Apple TV setup across with a backup code, or add your accounts in Settings › Connections.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Open Settings", systemImage: "gearshape", action: showSettings)
                .buttonStyle(.glassProminent)
                .tint(.white)
                .foregroundStyle(Theme.ink)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 22)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func homeRow(_ row: HomeRow) -> some View {
        switch row {
        case .myList:
            MyListRail()
        case .channels:
            FavouriteChannelsRail()
        case .teams:
            // Your teams' fixtures arrive with the Sports tab.
            EmptyView()
        default:
            if let section = Catalog.homeSection(row) {
                CatalogRail(section: section)
            }
        }
    }
}

/// The big card at the top of Home: backdrop, kicker, title, Details and My List.
private struct HeroCard: View {
    let item: TMDBItem
    let kicker: String
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        NavigationLink(value: item) {
            ZStack(alignment: .bottomLeading) {
                Artwork(url: item.backdropURL ?? item.posterURL)
                    .frame(maxWidth: .infinity)
                    .frame(height: 230)
                    .clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 8) {
                    Text(kicker)
                        .font(.caption.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(item.displayTitle)
                        .font(.title.weight(.black))
                        .lineLimit(2)
                    HStack(spacing: 10) {
                        Label("Details", systemImage: "info.circle")
                            .font(.subheadline.weight(.heavy))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .foregroundStyle(Theme.ink)
                            .background(.white, in: .capsule)
                        Button {
                            settings.toggleMyList(item)
                        } label: {
                            Label("My List", systemImage: settings.isInMyList(item) ? "checkmark" : "plus")
                                .font(.subheadline.weight(.bold))
                        }
                        .buttonStyle(.glass)
                    }
                }
                .padding(18)
            }
            .clipShape(.rect(cornerRadius: 22))
            .contentShape(.rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
    }
}
