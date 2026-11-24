import SwiftUI

// Fixture artwork and cards, as on the Apple TV (sized for iPhone and iPad).

extension Color {
    /// A colour from a hex string such as "da020e" or "#DA020E".
    init?(hex: String?) {
        guard var text = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}

/// A team crest on a light disc, so dark logos stay visible on any colour.
struct TeamLogo: View {
    let url: String?
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(.white.opacity(0.94))
            AsyncImage(url: url.flatMap { URL(string: $0) }) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "shield.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.gray)
            }
            .padding(size * 0.16)
        }
        .frame(width: size, height: size)
    }
}

private struct DiagonalHalf: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.58, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Two-tone artwork in the teams' colours with both crests (or a flag for a race).
struct FixtureArt: View {
    let fixture: Fixture

    private var homeColor: Color {
        if fixture.isRace { return Color(red: 0.82, green: 0.1, blue: 0.1) }
        return Color(hex: fixture.home?.color) ?? Color(red: 0.24, green: 0.3, blue: 0.42)
    }

    private var awayColor: Color {
        if fixture.isRace { return Color(red: 0.12, green: 0.12, blue: 0.15) }
        return Color(hex: fixture.away?.color) ?? Color(red: 0.13, green: 0.14, blue: 0.18)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                awayColor
                Color.black.opacity(0.35)
                DiagonalHalf().fill(homeColor)
                if fixture.isRace {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: geo.size.height * 0.34, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    HStack(spacing: 0) {
                        TeamLogo(url: fixture.home?.logo, size: geo.size.height * 0.46)
                            .frame(maxWidth: .infinity)
                        TeamLogo(url: fixture.away?.logo, size: geo.size.height * 0.46)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

/// A fixture as artwork, with the score or kick-off, and its title and details underneath.
struct FixtureTile: View {
    let fixture: Fixture
    var width: CGFloat = 260
    @ObservedObject private var liveScores = LiveScores.shared

    private var isLive: Bool { fixture.guideTime <= Date() }
    private var score: FixtureScore? { liveScores.score(for: fixture) }

    private var detail: String {
        if let score {
            return [fixture.competition, score.period].compactMap { $0 }.joined(separator: " · ")
        }
        let session = fixture.sessions.first { $0.date == fixture.guideTime }
        if fixture.isRace && isLive {
            return String(localized: "\(session?.name ?? String(localized: "Race")) in progress · \(fixture.competition)")
        }
        var parts = ["\(DayFormat.label(fixture.guideTime)) \(DayFormat.time(fixture.guideTime))"]
        if let session { parts.append(session.name) }
        parts.append(fixture.competition)
        return parts.joined(separator: " · ")
    }

    /// Top-left pill: kick-off time, LIVE, HT or FT.
    private var pill: (text: String, color: Color) {
        switch score?.phase {
        case .finished: return (score?.clock ?? "FT", .black.opacity(0.6))
        case .halfTime: return ("HT", .black.opacity(0.6))
        case .live: return ("LIVE", Theme.live)
        case nil: return isLive ? ("LIVE", Theme.live) : (DayFormat.time(fixture.guideTime), .black.opacity(0.5))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FixtureArt(fixture: fixture)
                .frame(width: width, height: width * 9 / 16)
                .overlay {
                    if let score { ScoreBadge(score: score, size: width / 440) }
                }
                .overlay(alignment: .topLeading) {
                    Text(pill.text)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(pill.color, in: .capsule)
                        .padding(10)
                }
                .clipShape(.rect(cornerRadius: 14))
            Text(fixture.title)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .frame(width: width, alignment: .leading)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: width, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The score between the two crests, with the minute (red while live) underneath.
struct ScoreBadge: View {
    let score: FixtureScore
    /// 1 at a 440-point-wide tile.
    var size: CGFloat = 1

    private var caption: String {
        switch score.phase {
        case .live: return score.clock
        case .halfTime: return "Half-time"
        case .finished: return score.clock == "FT" ? "Full time" : score.clock
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(score.line)
                .font(.system(size: 46 * size, weight: .heavy))
                .monospacedDigit()
            Text(caption)
                .font(.system(size: max(18 * size, 10), weight: .bold))
                .foregroundStyle(score.phase == .live ? Theme.live : .white.opacity(0.8))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18 * size)
        .padding(.vertical, 10 * size)
        .background(.black.opacity(0.55), in: .rect(cornerRadius: 18 * size))
    }
}

/// A fixture later in the window, as a list row: crests, day, title, time and competition.
struct UpcomingFixtureRow: View {
    let fixture: Fixture

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if fixture.isRace {
                    Image(systemName: "flag.checkered")
                        .font(.title2.weight(.bold))
                        .frame(width: 66)
                } else {
                    HStack(spacing: -10) {
                        TeamLogo(url: fixture.home?.logo, size: 38)
                        TeamLogo(url: fixture.away?.logo, size: 38)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(fixture.title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                Text("\(DayFormat.label(fixture.guideTime)) \(DayFormat.time(fixture.guideTime)) · \(fixture.competition)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .glassPanel(cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }
}

/// A followed team with its next fixture.
struct TeamTile: View {
    let team: FavouriteTeam
    let next: Fixture?

    private var nextLine: String {
        guard let next else { return String(localized: "No fixture soon") }
        return String(localized: "Next: \(DayFormat.label(next.guideTime)) \(DayFormat.time(next.guideTime))")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Rectangle().fill(.white.opacity(0.1))
                if team.isF1 {
                    Image(systemName: "flag.checkered").font(.largeTitle.weight(.bold))
                } else {
                    AsyncImage(url: team.logo.flatMap { URL(string: $0) }) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "shield").font(.largeTitle)
                    }
                    .padding(18)
                }
            }
            .frame(width: 150, height: 96)
            .clipShape(.rect(cornerRadius: 14))
            Text(team.name)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
            Text(nextLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Your teams' coming fixtures, on Home (the "My Teams" row in Settings › Home screen).
struct UpcomingFixturesRail: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var fixtures: [Fixture] = []

    private var loadKey: String {
        settings.prefs.favouriteTeams.map(\.id).joined(separator: ",") + "|\(settings.prefs.sportsDaysAhead)"
    }

    var body: some View {
        Group {
            if !fixtures.isEmpty {
                Rail(title: "My Teams") {
                    ForEach(fixtures) { fixture in
                        NavigationLink(value: fixture) { FixtureTile(fixture: fixture, width: 240) }
                            .buttonStyle(.plain)
                            .matchReminderMenu(fixture)
                    }
                }
            }
        }
        .task(id: loadKey) {
            let teams = settings.prefs.favouriteTeams
            guard !teams.isEmpty else {
                fixtures = []
                return
            }
            let all = await SportsLoader.upcoming(teams: teams, days: settings.prefs.sportsDaysAhead)
            fixtures = Array(all.prefix(12))
        }
        .task { await LiveScores.shared.run() }
    }
}
