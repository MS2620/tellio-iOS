import SwiftUI

/// The Search tab. Finds channels across every group for now; films and series join when
/// Browse is built.
struct SearchView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var parental = ParentalLock.shared

    @State private var query = ""
    @State private var channels: [XtreamChannel] = []
    @State private var epg: [Int: [XtreamEPGEntry]] = [:]
    @State private var searching = false
    @State private var now = Date()

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Group {
                if trimmed.isEmpty {
                    ContentUnavailableView {
                        Label("Search", systemImage: "magnifyingglass")
                    } description: {
                        Text(settings.xtream.isConfigured
                             ? "Find channels by name. Films and series are coming."
                             : "Add an IPTV account in Settings › Connections to search channels.")
                    }
                } else if channels.isEmpty {
                    if searching {
                        ProgressView()
                    } else {
                        ContentUnavailableView.search(text: trimmed)
                    }
                } else {
                    results
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appBackground()
            .navigationTitle("Search")
        }
        .searchable(text: $query, prompt: "Channels")
        .task(id: query) { await search() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                now = Date()
            }
        }
    }

    private var results: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                SectionHeader(String(localized: "\(channels.count) channels"))
                    .padding(.horizontal, 4)
                ForEach(channels) { channel in
                    Button {
                        ChannelPlayback.play(channel, in: channels, settings: settings,
                                             nowPlaying: NowNext.current(epg[channel.id], at: Date())?.title)
                    } label: {
                        ChannelRow(channel: channel,
                                   number: settings.prefs.showChannelNumbers ? channel.number : nil,
                                   favourite: settings.prefs.favouriteChannelIDs.contains(channel.id),
                                   folderName: channel.folderName,
                                   entries: epg[channel.id],
                                   now: now,
                                   showsGuide: settings.prefs.showEPG)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                }
            }
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func search() async {
        let text = trimmed
        guard !text.isEmpty else {
            channels = []
            return
        }
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        searching = true
        let found = await ChannelPlayback.search(text, settings: settings, parental: parental)
        guard !Task.isCancelled else { return }
        channels = found
        searching = false
        guard settings.prefs.showEPG else { return }
        let pending = found.prefix(60).map(\.id).filter { epg[$0] == nil }
        await NowNext.load(pending, client: settings.xtreamClient) { batch in
            epg.merge(batch) { _, new in new }
        }
    }
}
