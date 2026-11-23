import SwiftUI

/// Sports: your teams' fixtures today (with live scores) and over the next days, your teams
/// with their next match, and league tables. Teams are chosen with My Teams (shared with the
/// Apple TV through the backup).
struct SportsView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var liveScores = LiveScores.shared
    @State private var fixtures: [Fixture] = []
    @State private var loading = false

    private var teams: [FavouriteTeam] { settings.prefs.favouriteTeams }
    private var days: Int { settings.prefs.sportsDaysAhead }
    private var loadKey: String { teams.map(\.id).joined(separator: ",") + "|\(days)" }

    /// On today, or already under way.
    private var today: [Fixture] {
        fixtures.filter { Calendar.current.isDateInToday($0.guideTime) || $0.guideTime <= Date() }
    }

    private var later: [Fixture] {
        let todayIDs = Set(today.map(\.id))
        return fixtures.filter { !todayIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Text("Next \(days) days · all competitions")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)

                    if teams.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Choose your teams to see when they next play or race, with live scores and the channels showing each match.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            NavigationLink {
                                TeamsManagerView()
                            } label: {
                                Label("Choose teams", systemImage: "star")
                                    .font(.subheadline.weight(.bold))
                            }
                            .buttonStyle(.glassProminent)
                            .tint(.white)
                            .foregroundStyle(Theme.ink)
                        }
                        .padding(18)
                        .glassPanel(cornerRadius: 22)
                        .padding(.horizontal, 20)
                    } else if loading && fixtures.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else if fixtures.isEmpty {
                        Text("No fixtures for your teams in the next \(days) days.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                    }

                    if !today.isEmpty {
                        Rail(title: "Today") {
                            ForEach(today) { fixture in
                                NavigationLink(value: fixture) { FixtureTile(fixture: fixture, width: 300) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }

                    if !later.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            RailTitle(text: "Coming up")
                            LazyVStack(spacing: 8) {
                                ForEach(later) { fixture in
                                    NavigationLink(value: fixture) { UpcomingFixtureRow(fixture: fixture) }
                                        .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    if !teams.isEmpty {
                        Rail(title: "My Teams") {
                            ForEach(teams) { team in
                                let next = fixtures.first {
                                    $0.followed.contains(team.name) && liveScores.score(for: $0)?.phase != .finished
                                }
                                if let next {
                                    NavigationLink(value: next) { TeamTile(team: team, next: next) }
                                        .buttonStyle(.plain)
                                } else {
                                    TeamTile(team: team, next: nil)
                                }
                            }
                        }
                        LeagueTablesSection(teams: teams)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .appBackground()
            .navigationTitle("Sports")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        TeamsManagerView()
                    } label: {
                        Label("My Teams", systemImage: "star")
                    }
                }
            }
            .refreshable { await load() }
            .task(id: loadKey) { await load() }
            .task { await liveScores.run() }
            .sportsDestinations()
        }
    }

    private func load() async {
        guard !teams.isEmpty else {
            fixtures = []
            return
        }
        loading = true
        fixtures = await SportsLoader.upcoming(teams: teams, days: days)
        loading = false
    }
}

extension View {
    /// The fixture page; added at the root of each tab's navigation stack that shows fixtures.
    func sportsDestinations() -> some View {
        navigationDestination(for: Fixture.self) { FixtureDetailView(fixture: $0) }
    }
}
