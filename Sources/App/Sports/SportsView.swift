import SwiftUI

/// Sports: your teams' fixtures today (with live scores) and over the next days, your teams
/// with their next match, and league tables. Teams are chosen with My Teams (shared with the
/// Apple TV through the backup).
struct SportsView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var liveScores = LiveScores.shared
    @ObservedObject private var router = AppRouter.shared
    @State private var fixtures: [Fixture] = []
    @State private var loading = false
    /// Today's games in each followed competition that has some.
    @State private var competitionGames: [(competition: FavouriteCompetition, fixtures: [Fixture])] = []
    @State private var loadingCompetitions = false

    private var teams: [FavouriteTeam] { settings.prefs.favouriteTeams }
    private var days: Int { settings.prefs.sportsDaysAhead }
    private var loadKey: String { teams.map(\.id).joined(separator: ",") + "|\(days)" }
    private var competitions: [FavouriteCompetition] { settings.prefs.favouriteCompetitions }
    private var competitionsKey: String { competitions.map(\.id).joined(separator: ",") }

    /// On today, or already under way.
    private var today: [Fixture] {
        fixtures.filter { Calendar.current.isDateInToday($0.guideTime) || $0.guideTime <= Date() }
    }

    private var later: [Fixture] {
        let todayIDs = Set(today.map(\.id))
        return fixtures.filter { !todayIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack(path: $router.sportsPath) {
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
                                    .matchReminderMenu(fixture)
                            }
                        }
                    }

                    competitionsSection

                    if !later.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            RailTitle(text: "Coming up")
                            LazyVStack(spacing: 8) {
                                ForEach(later) { fixture in
                                    NavigationLink(value: fixture) { UpcomingFixtureRow(fixture: fixture) }
                                        .buttonStyle(.plain)
                                        .matchReminderMenu(fixture)
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
            .refreshable {
                async let teams: Void = load()
                async let others: Void = loadCompetitions()
                _ = await (teams, others)
            }
            .task(id: loadKey) { await load() }
            .task(id: competitionsKey) { await loadCompetitions() }
            .task { await liveScores.run() }
            .sportsDestinations()
        }
    }

    /// Today in your competitions: every game of the day in each followed competition, for
    /// quick access to matches your teams aren't in. Fixtures and tables stay your teams'.
    @ViewBuilder
    private var competitionsSection: some View {
        if !competitions.isEmpty {
            if competitionGames.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    RailTitle(text: "Today in your competitions")
                    Group {
                        if loadingCompetitions {
                            ProgressView()
                        } else {
                            Text("No games today in your competitions.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            ForEach(competitionGames, id: \.competition.id) { entry in
                Rail(title: String(localized: "\(entry.competition.name) · \(entry.fixtures.count) today")) {
                    ForEach(entry.fixtures) { fixture in
                        NavigationLink(value: fixture) { FixtureTile(fixture: fixture, width: 300) }
                            .buttonStyle(.plain)
                            .matchReminderMenu(fixture)
                    }
                }
            }
        }
    }

    private func loadCompetitions() async {
        guard !competitions.isEmpty else {
            competitionGames = []
            return
        }
        loadingCompetitions = true
        competitionGames = await SportsLoader.today(in: competitions, teams: teams)
        loadingCompetitions = false
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
    /// Long-press › Remind me (or Cancel reminder), for a match that hasn't started.
    func matchReminderMenu(_ fixture: Fixture) -> some View {
        contextMenu {
            if fixture.date > Date() { MatchReminderButton(fixture: fixture) }
        }
    }

    /// The fixture page; added at the root of each tab's navigation stack that shows fixtures.
    func sportsDestinations() -> some View {
        navigationDestination(for: Fixture.self) { FixtureDetailView(fixture: $0) }
    }
}

/// Remind me / Cancel reminder for a match, asking for notifications the first time.
struct MatchReminderButton: View {
    let fixture: Fixture
    var iconOnly = false
    @ObservedObject private var reminders = ReminderStore.shared

    private var isSet: Bool { reminders.isSet(fixture: fixture) }

    var body: some View {
        Button {
            if !isSet { Task { await ReminderNotifications.requestPermission() } }
            reminders.toggle(fixture: fixture)
        } label: {
            Label(isSet ? String(localized: "Cancel reminder") : String(localized: "Remind me"),
                  systemImage: isSet ? "bell.slash" : "bell")
                .labelStyle(iconOnly ? AnyLabelStyle(.iconOnly) : AnyLabelStyle(.titleAndIcon))
        }
    }
}

/// Lets the label style be chosen at run time.
private struct AnyLabelStyle: LabelStyle {
    private let make: (Configuration) -> AnyView

    init<Style: LabelStyle>(_ style: Style) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}
