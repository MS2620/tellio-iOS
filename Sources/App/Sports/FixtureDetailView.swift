import SwiftUI

/// A fixture: artwork, score, venue, competition and time; a race weekend's sessions; and the
/// channels in your TV guide showing it (found by the shared guide search), tap to watch; and
/// the game in your addons.
struct FixtureDetailView: View {
    let fixture: Fixture
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var store = ChannelSearchStore.shared
    @ObservedObject private var liveScores = LiveScores.shared
    @State private var showingSportsChannels = false
    @State private var addonHits: [AddonSportsHit] = []
    @State private var addonSearching = false
    /// Whether any addon lists something other than films and series; otherwise the section stays hidden.
    @State private var addonsHaveLive = false

    private var unlockedAddons: [AddonEntry] {
        settings.addons.filter { !ParentalLock.shared.isLocked(addon: $0, prefs: settings.prefs) }
    }

    /// The guide search is done (or there's no IPTV account), so its channels can be looked for in addons too.
    private var guideSearchDone: Bool { !settings.xtream.isConfigured || !searching }

    private var score: FixtureScore? { liveScores.score(for: fixture) }
    private var entry: ChannelSearchStore.Entry? { store.entries[fixture.id] }
    private var result: ChannelSearch { entry?.result ?? ChannelSearch() }
    private var searching: Bool { entry?.searching ?? true }
    private var matches: [ChannelMatch] { result.matches }

    /// The provider's guide doesn't reach the fixture yet (guides rarely go past about a week).
    private var notListedYet: Bool {
        if let ends = result.guideEnds { return fixture.guideTime > ends }
        return fixture.guideTime > Date().addingTimeInterval(8 * 86_400)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FixtureArt(fixture: fixture)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay {
                        if let score { ScoreBadge(score: score, size: 0.9) }
                    }
                    .clipShape(.rect(cornerRadius: 22))

                VStack(alignment: .leading, spacing: 8) {
                    Text(displayTitle)
                        .font(.title2.weight(.black))
                        .lineLimit(3)
                    if let score {
                        HStack(spacing: 8) {
                            Text(score.phase == .live ? String(localized: "● LIVE \(score.clock)") : score.clock)
                                .font(.caption.weight(.heavy))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(score.phase == .live ? Theme.live : .black.opacity(0.45), in: .capsule)
                            if let period = score.period {
                                Text(period).font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                    if let subtitle = fixture.subtitle, !subtitle.isEmpty {
                        Label(subtitle, systemImage: fixture.isRace ? "flag.checkered" : "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Label(fixture.competition, systemImage: "trophy")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Label(dateLine, systemImage: "calendar")
                        .font(.subheadline.weight(.bold))
                }

                if fixture.isRace {
                    SettingsGroup("Weekend schedule") {
                        ForEach(fixture.sessions, id: \.self) { session in
                            HStack {
                                Text(session.name)
                                Spacer()
                                Text(session.date.formatted(.dateTime.weekday(.abbreviated).day().month().hour().minute()))
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                            .opacity(session.date < Date() ? 0.5 : 1)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                }

                watchPanel
                addonPanel

                if !matches.isEmpty && !searching {
                    SettingsNote([result.details, String(localized: "Hidden groups and channels are skipped.")]
                        .compactMap { $0 }.joined(separator: " "))
                }
                if !fixture.broadcasts.isEmpty {
                    Text("Listed broadcasters: \(fixture.broadcasts.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .appBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task { search(force: false) }
        .task { await liveScores.run() }
        .task(id: guideSearchDone) { await searchAddons() }
        .sheet(isPresented: $showingSportsChannels) {
            SportsChannelsSheet()
        }
    }

    /// "Portugal – Denmark", or "Portugal 2 – 1 Denmark" once started.
    private var displayTitle: String {
        if let score, let home = fixture.home?.name, let away = fixture.away?.name {
            return "\(home) \(score.line) \(away)"
        }
        return fixture.title.replacingOccurrences(of: " v ", with: " – ")
    }

    /// "Saturday 14 November at 19:45".
    private var dateLine: String {
        String(localized: "\(fixture.guideTime.formatted(.dateTime.weekday(.wide).day().month(.wide))) at \(DayFormat.time(fixture.guideTime))")
    }

    private var progressText: String {
        guard let entry, entry.total > 0 else { return String(localized: "Searching your TV guide…") }
        return String(localized: "Checking channels… \(entry.checked) of \(entry.total)")
    }

    private var watchPanel: some View {
        SettingsGroup("Watch") {
            if matches.isEmpty {
                guideSection
            } else {
                ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                    Button {
                        play(index)
                    } label: {
                        HStack(spacing: 12) {
                            ChannelLogo(channel: match.channel, width: 56, height: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(match.channel.name)
                                    .font(.subheadline.weight(.bold))
                                    .lineLimit(1)
                                Text(programmeLine(match.programme))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "play.fill").foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
                if searching {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(progressText).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(16)
                }
            }
        }
    }

    /// The game in the user's addons: listings of the game itself, or the channels showing it.
    @ViewBuilder
    private var addonPanel: some View {
        if addonsHaveLive {
            SettingsGroup("From your addons") {
                if addonHits.isEmpty {
                    if addonSearching {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Searching your addons…").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        Text("Not found in your addons. Addons that list live games or channels are searched by the team names and the channels showing it.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(16)
                    }
                }
                ForEach(addonHits.filter { $0.kind != .sportChannel }) { hit in
                    addonRow(hit)
                }
                let maybe = addonHits.filter { $0.kind == .sportChannel }
                if !maybe.isEmpty {
                    Text("CHANNELS FOR THIS SPORT · MAY BE SHOWING IT")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    ForEach(maybe) { hit in
                        addonRow(hit)
                    }
                }
            }
        }
    }

    private func addonRow(_ hit: AddonSportsHit) -> some View {
        Button {
            playAddon(hit)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: hit.kind == .game ? "sportscourt" : "tv")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.16), in: .rect(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(hit.title)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(2)
                    Text([hit.stream.headline, hit.addonName].joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Image(systemName: "play.fill").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func searchAddons() async {
        let addons = unlockedAddons
        guard !addons.isEmpty else { return }
        addonsHaveLive = await AddonSports.hasLiveCatalogues(addons)
        guard addonsHaveLive else { return }
        addonSearching = true
        let done = guideSearchDone
        let channelNames = done ? matches.map(\.channel.providerName) : []
        let hits = await AddonSports.search(fixture, addons: addons, channelNames: channelNames)
        guard !Task.isCancelled else { return }
        addonHits = hits
        // Until the guide search ends, more channels (and so more addon results) may follow.
        addonSearching = !done
    }

    private func playAddon(_ hit: AddonSportsHit) {
        guard let url = hit.stream.playableURL else { return }
        SystemPlayer.present(PlaybackRequest(url: url, title: displayTitle, subtitle: hit.addonName,
                                             isLive: true, httpHeaders: hit.stream.requestHeaders))
    }

    @ViewBuilder
    private var guideSection: some View {
        if !settings.xtream.isConfigured {
            Text("Add your IPTV login in Settings › Connections to find this in your TV guide.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(16)
        } else if searching {
            HStack(spacing: 10) {
                ProgressView()
                Text(progressText).font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Label(notListedYet ? "Not in your TV guide yet" : "Not found in your TV guide", systemImage: "clock")
                    .font(.headline)
                Text(notFoundDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button("Check again", systemImage: "arrow.clockwise") { search(force: true) }
                        .buttonStyle(.glass)
                    Button("Sports channels", systemImage: "antenna.radiowaves.left.and.right") {
                        showingSportsChannels = true
                    }
                    .buttonStyle(.glass)
                }
                .font(.subheadline.weight(.bold))
                if let details = result.details {
                    // What was searched, so a screenshot shows where it went wrong.
                    Text(details).font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .padding(16)
        }
    }

    private var notFoundDetail: String {
        if notListedYet {
            let reach = result.guideEnds.map {
                String(localized: "Your provider's guide reaches \($0.formatted(.dateTime.weekday(.wide).day().month(.wide))).") + " "
            } ?? ""
            return reach + String(localized: "Channels showing this will appear here once it's listed, usually a day or two before.")
        }
        return String(localized: "None of your channels list it at that time. Listings can be added late, so try again closer to the start.")
    }

    /// The listing, its times and the account it's on.
    private func programmeLine(_ entry: XtreamEPGEntry) -> String {
        let times = [entry.start, entry.end].compactMap { $0 }.map(DayFormat.time).joined(separator: "–")
        return [entry.title, times, settings.xtream.displayName].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func search(force: Bool) {
        guard settings.xtream.isConfigured else { return }
        store.start(fixture, settings: settings, force: force)
    }

    private func play(_ index: Int) {
        let channels = matches.map(\.channel)
        ChannelPlayback.play(channels[index], in: channels, settings: settings,
                             nowPlaying: matches[index].programme.title)
    }
}

/// Every channel that looks like a sports channel, to pick one by hand.
private struct SportsChannelsSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var channels: [XtreamChannel] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            List {
                if loading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if channels.isEmpty {
                    Text("No sports channels found in your groups.").foregroundStyle(.secondary)
                }
                ForEach(channels) { channel in
                    Button {
                        dismiss()
                        ChannelPlayback.play(channel, in: channels, settings: settings, nowPlaying: nil)
                    } label: {
                        HStack(spacing: 12) {
                            ChannelLogo(channel: channel, width: 56, height: 32)
                            Text(channel.name).lineLimit(1)
                        }
                    }
                }
            }
            .navigationTitle("Sports channels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .task {
            let prefs = settings.prefs
            channels = await ChannelFinder.sportsChannels(client: settings.xtreamClient,
                                                          hiddenCategories: prefs.hiddenCategoryIDs,
                                                          hiddenChannels: prefs.hiddenChannelIDs)
            loading = false
        }
    }
}
