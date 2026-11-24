import SwiftUI

/// Which sport the team search is narrowed to.
private enum SportFilter: String, CaseIterable, Identifiable {
    case all, football, f1, rugby, cricket, nfl, nba, nhl, mlb

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .football: return "Football"
        case .f1: return "Formula 1"
        case .rugby: return "Rugby"
        case .cricket: return "Cricket"
        case .nfl: return "NFL"
        case .nba: return "NBA"
        case .nhl: return "NHL"
        case .mlb: return "MLB"
        }
    }

    func includes(_ result: TeamSearchResult) -> Bool {
        switch self {
        case .all: return true
        case .football: return result.sport == "soccer"
        case .f1: return result.sport == "f1"
        case .rugby: return result.sport == "rugby" || result.sport == SuperLeagueClient.sport
        case .cricket: return result.sport == "cricket"
        case .nfl: return result.league == "nfl"
        case .nba: return result.league == "nba"
        case .nhl: return result.league == "nhl"
        case .mlb: return result.league == "mlb"
        }
    }
}

/// My Teams: the teams you follow (swipe to remove), search every team, or browse by league.
struct TeamsManagerView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var query = ""
    @State private var results: [TeamSearchResult] = []
    @State private var searching = false
    @State private var filter: SportFilter = .all
    @State private var constructors: [F1Constructor] = []
    @State private var leagueNames: [String: String] = [:]

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var shownResults: [TeamSearchResult] { results.filter { filter.includes($0) } }

    var body: some View {
        List {
            if trimmed.count >= 2 {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SportFilter.allCases) { option in
                                Button(option.label) { filter = option }
                                    .font(.subheadline.weight(.bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .foregroundStyle(option == filter ? Theme.ink : .white)
                                    .background(option == filter ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.12)),
                                                in: .capsule)
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    if searching && results.isEmpty {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if shownResults.isEmpty {
                        Text("No teams found for “\(trimmed)”.").foregroundStyle(.secondary)
                    }
                    ForEach(shownResults) { result in
                        Button {
                            toggle(result)
                        } label: {
                            TeamRow(name: result.name, detail: describe(result),
                                    logo: result.sport == "f1" ? nil : result.logo,
                                    isF1: result.sport == "f1", isFollowing: isFollowing(result))
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Results")
                }
            } else {
                Section {
                    if settings.prefs.favouriteTeams.isEmpty {
                        Text("No teams yet. Search above, or browse by league below.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(settings.prefs.favouriteTeams) { team in
                        TeamRow(name: team.name, detail: team.leagueName, logo: team.logo,
                                isF1: team.isF1, isFollowing: nil)
                    }
                    .onDelete { settings.prefs.favouriteTeams.remove(atOffsets: $0) }
                    .onMove { settings.prefs.favouriteTeams.move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    Text("Following · \(settings.prefs.favouriteTeams.count)")
                } footer: {
                    if !settings.prefs.favouriteTeams.isEmpty {
                        Text("Swipe left on a team to stop following it.")
                    }
                }

                Section("Browse by league") {
                    NavigationLink { FootballLeaguesView() } label: {
                        Label("Football", systemImage: "soccerball")
                    }
                    NavigationLink { F1TeamsView() } label: {
                        Label("Formula 1", systemImage: "flag.checkered")
                    }
                    NavigationLink {
                        LeagueListView(title: "Rugby", leagues: SportsCatalog.rugby + SportsCatalog.rugbyLeague)
                    } label: {
                        Label("Rugby", systemImage: "figure.rugby")
                    }
                    NavigationLink { CricketLeaguesView() } label: {
                        Label("Cricket", systemImage: "figure.cricket")
                    }
                    ForEach(SportsCatalog.us) { league in
                        NavigationLink { TeamPickerView(league: league) } label: {
                            Label(league.name, systemImage: "sportscourt")
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("My Teams")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search teams, e.g. Porto, McLaren, Bath")
        .autocorrectionDisabled()
        .task { await loadNames() }
        .task(id: trimmed) { await search() }
    }

    private func loadNames() async {
        if let leagues = try? await ESPNClient().footballLeagues() {
            leagueNames = Dictionary(leagues.map { ($0.slug, $0.name) }, uniquingKeysWith: { first, _ in first })
        }
        constructors = (try? await F1Client().constructors()) ?? []
    }

    private func search() async {
        let text = trimmed
        guard text.count >= 2 else {
            results = []
            searching = false
            return
        }
        searching = true
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }
        var found = (try? await ESPNClient().searchTeams(text)) ?? []
        let racing = constructors
            .filter { $0.name.localizedCaseInsensitiveContains(text) }
            .map { TeamSearchResult(sport: "f1", league: "f1", teamID: $0.id, name: $0.name, logo: nil, color: nil) }
        found = racing + found
        guard !Task.isCancelled, text == trimmed else { return }
        results = found
        searching = false
    }

    private func leagueName(_ result: TeamSearchResult) -> String {
        switch result.sport {
        case "f1": return "Formula 1"
        case "soccer": return leagueNames[result.league] ?? "Football"
        case "rugby": return SportsCatalog.rugby.first { $0.slug == result.league }?.name ?? "Rugby"
        case SuperLeagueClient.sport: return SuperLeagueClient.league.name
        case "cricket": return "Cricket"
        default: return result.league.uppercased()
        }
    }

    private func describe(_ result: TeamSearchResult) -> String {
        let sport: String
        switch result.sport {
        case "f1": return "Formula 1"
        case "soccer": sport = "Football"
        case "rugby", SuperLeagueClient.sport: sport = "Rugby"
        case "cricket": sport = "Cricket"
        case "football": sport = "American football"
        case "basketball": sport = "Basketball"
        case "hockey": sport = "Ice hockey"
        case "baseball": sport = "Baseball"
        default: sport = result.sport.capitalized
        }
        let league = leagueName(result)
        return league == sport ? sport : "\(sport) · \(league)"
    }

    private func isFollowing(_ result: TeamSearchResult) -> Bool {
        settings.prefs.favouriteTeams.contains { $0.sport == result.sport && $0.teamID == result.teamID }
    }

    private func toggle(_ result: TeamSearchResult) {
        if isFollowing(result) {
            settings.prefs.favouriteTeams.removeAll { $0.sport == result.sport && $0.teamID == result.teamID }
        } else {
            settings.prefs.favouriteTeams.append(FavouriteTeam(
                sport: result.sport, league: result.league, leagueName: leagueName(result),
                teamID: result.teamID, name: result.name, logo: result.logo, color: result.color
            ))
        }
    }
}

/// A team: crest (or a flag for F1), name and league, and whether you follow it.
private struct TeamRow: View {
    let name: String
    let detail: String?
    let logo: String?
    var isF1 = false
    /// nil hides the follow mark (the Following list).
    let isFollowing: Bool?

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if isF1 {
                    Image(systemName: "flag.checkered").font(.title3)
                } else {
                    AsyncImage(url: logo.flatMap { URL(string: $0) }) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "shield").foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.body.weight(.semibold))
                if let detail, !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let isFollowing {
                Image(systemName: isFollowing ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundStyle(isFollowing ? .white : .secondary)
                    .accessibilityLabel(isFollowing ? "Following" : "Follow")
            }
        }
        .contentShape(.rect)
    }
}

private struct FootballLeaguesView: View {
    @State private var leagues: [SportLeague] = []
    @State private var error: String?

    var body: some View {
        Group {
            if let error {
                Text(error).foregroundStyle(.secondary).padding()
            } else if leagues.isEmpty {
                ProgressView()
            } else {
                LeagueListView(title: "Football", leagues: leagues)
            }
        }
        .task {
            do {
                leagues = try await ESPNClient().footballLeagues()
                if leagues.isEmpty { error = "No leagues found." }
            } catch {
                self.error = "Couldn't load leagues: \(error.localizedDescription)"
            }
        }
    }
}

/// International sides, then the competitions with cricket in the next 30 days.
private struct CricketLeaguesView: View {
    @State private var leagues: [SportLeague] = []

    var body: some View {
        Group {
            if leagues.isEmpty {
                ProgressView()
            } else {
                LeagueListView(title: "Cricket", leagues: leagues)
            }
        }
        .task { leagues = await CricketClient().leagues() }
    }
}

private struct LeagueListView: View {
    let title: String
    let leagues: [SportLeague]
    @State private var filter = ""

    private var shown: [SportLeague] {
        filter.isEmpty ? leagues : leagues.filter { $0.name.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        List(shown) { league in
            NavigationLink(league.name) { TeamPickerView(league: league) }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle(title)
        .searchable(text: $filter, prompt: "Find a competition")
    }
}

private struct TeamPickerView: View {
    let league: SportLeague
    @EnvironmentObject private var settings: AppSettings
    @State private var teams: [ESPNTeam] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        List {
            if loading {
                ProgressView().frame(maxWidth: .infinity)
            } else if let error {
                Text(error).foregroundStyle(.secondary)
            } else if teams.isEmpty {
                Text("No teams listed for this competition right now.").foregroundStyle(.secondary)
            }
            ForEach(teams, id: \.id) { team in
                Button {
                    toggle(team)
                } label: {
                    TeamRow(name: team.displayName, detail: nil, logo: team.logoURL, isFollowing: isFavourite(team))
                }
                .buttonStyle(.plain)
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle(league.name)
        .task {
            do {
                teams = try await ESPNClient().teams(in: league)
            } catch {
                self.error = "Couldn't load teams: \(error.localizedDescription)"
            }
            loading = false
        }
    }

    private func favouriteID(_ team: ESPNTeam) -> String { "\(league.sport)/\(league.slug)/\(team.id)" }

    private func isFavourite(_ team: ESPNTeam) -> Bool {
        settings.prefs.favouriteTeams.contains { $0.id == favouriteID(team) }
    }

    private func toggle(_ team: ESPNTeam) {
        if isFavourite(team) {
            settings.prefs.favouriteTeams.removeAll { $0.id == favouriteID(team) }
        } else {
            settings.prefs.favouriteTeams.append(FavouriteTeam(
                sport: league.sport, league: league.slug, leagueName: league.name,
                teamID: team.id, name: team.displayName, logo: team.logoURL, color: team.color
            ))
        }
    }
}

private struct F1TeamsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var constructors: [F1Constructor] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        List {
            Section {
                if loading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if let error {
                    Text(error).foregroundStyle(.secondary)
                }
                ForEach(constructors) { constructor in
                    Button {
                        toggle(constructor)
                    } label: {
                        TeamRow(name: constructor.name, detail: nil, logo: nil, isF1: true,
                                isFollowing: isFavourite(constructor))
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("Following any team shows each race weekend in Sports.")
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Formula 1")
        .task {
            do {
                constructors = try await F1Client().constructors()
            } catch {
                self.error = "Couldn't load teams: \(error.localizedDescription)"
            }
            loading = false
        }
    }

    private func isFavourite(_ constructor: F1Constructor) -> Bool {
        settings.prefs.favouriteTeams.contains { $0.isF1 && $0.teamID == constructor.id }
    }

    private func toggle(_ constructor: F1Constructor) {
        if isFavourite(constructor) {
            settings.prefs.favouriteTeams.removeAll { $0.isF1 && $0.teamID == constructor.id }
        } else {
            settings.prefs.favouriteTeams.append(FavouriteTeam(
                sport: "f1", league: "f1", leagueName: "Formula 1",
                teamID: constructor.id, name: constructor.name, logo: nil
            ))
        }
    }
}
