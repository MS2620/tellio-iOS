import AetherEngine
import AVFoundation
import SwiftUI

/// The channels in multiview: two on iPhone, four on iPad. Adding one opens multiview full
/// screen; closing it stops every stream.
@MainActor
final class MultiviewStore: ObservableObject {
    static let shared = MultiviewStore()
    static var maxChannels: Int { UIDevice.current.userInterfaceIdiom == .pad ? 4 : 2 }

    @Published private(set) var channels: [XtreamChannel] = []
    /// Opens the channel picker as soon as multiview appears (started from the player).
    @Published var pickOnOpen = false
    private var screen: PlayerHostingController?

    var isShowing: Bool { screen != nil }
    var isFull: Bool { channels.count >= Self.maxChannels }

    /// Adds a channel and shows multiview. `after` waits for the player to finish closing.
    func add(_ channel: XtreamChannel, after delay: Duration = .zero, pickNext: Bool = false) {
        if !channels.contains(where: { $0.id == channel.id }), !isFull {
            channels.append(channel)
        }
        pickOnOpen = pickNext && !isFull
        guard screen == nil else { return }
        Task { @MainActor in
            if delay > .zero { try? await Task.sleep(for: delay) }
            present()
        }
    }

    func remove(_ id: Int) {
        channels.removeAll { $0.id == id }
        if channels.isEmpty { close() }
    }

    func close() {
        channels = []
        pickOnOpen = false
        if let shown = screen {
            screen = nil
            shown.dismiss(animated: true)
        }
    }

    private func present() {
        guard screen == nil, !channels.isEmpty,
              let settings = PlayerSession.shared.settings,
              let top = SystemPlayer.topController() else { return }
        let controller = PlayerHostingController(rootView: AnyView(
            MultiviewScreen(store: self).environmentObject(settings)
        ))
        controller.modalPresentationStyle = .fullScreen
        screen = controller
        top.present(controller, animated: true)
    }
}

/// Several live channels at once, each on its own engine. One is heard at a time.
///
/// Tap a picture to hear it, double-tap to make it full screen (and again to go back).
/// The ✕ on a picture takes that channel out; the ✕ at the top leaves multiview.
struct MultiviewScreen: View {
    @ObservedObject var store: MultiviewStore
    @EnvironmentObject private var settings: AppSettings

    @State private var engines: [Int: AetherEngine] = [:]
    @State private var audibleID: Int?
    @State private var expandedID: Int?
    @State private var picking = false
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let expandedID, let channel = store.channels.first(where: { $0.id == expandedID }) {
                tile(channel, expanded: true)
                    .ignoresSafeArea()
            } else {
                GeometryReader { proxy in
                    grid(in: proxy.size)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 60)
            }

            if controlsVisible {
                topBar.transition(.opacity)
            }
        }
        .contentShape(.rect)
        .onTapGesture { showControls() }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .task(id: store.channels.map(\.id)) { await syncEngines() }
        .onChange(of: audibleID) { _, _ in applyVolumes() }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            showControls()
            if store.pickOnOpen {
                store.pickOnOpen = false
                picking = true
            }
        }
        .onDisappear {
            hideTask?.cancel()
            for engine in engines.values { engine.stop() }
            engines = [:]
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sheet(isPresented: $picking) {
            MultiviewChannelPicker(exclude: Set(store.channels.map(\.id))) { channel in
                picking = false
                store.add(channel)
                audibleID = channel.id
            }
            .environmentObject(settings)
        }
    }

    // MARK: Layout

    /// Side by side in landscape, stacked in portrait; three or four as a 2×2 grid. Every
    /// picture is 16:9 and as large as fits.
    private func grid(in size: CGSize) -> some View {
        let channels = store.channels
        let count = max(channels.count, 1)
        let landscape = size.width > size.height
        let columns = count == 1 ? 1 : (count == 2 ? (landscape ? 2 : 1) : 2)
        let rows = Int((Double(count) / Double(columns)).rounded(.up))
        let gap: CGFloat = 8
        let fitWidth = (size.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let fitHeight = (size.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
        let width = max(0, min(fitWidth, fitHeight * 16 / 9))
        let height = width * 9 / 16
        return VStack(spacing: gap) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(channels.dropFirst(row * columns).prefix(columns)) { channel in
                        tile(channel, expanded: false)
                            .frame(width: width, height: height)
                    }
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func tile(_ channel: XtreamChannel, expanded: Bool) -> some View {
        MultiviewTile(engine: engines[channel.id], channel: channel,
                      audible: audibleID == channel.id, expanded: expanded,
                      showsControls: controlsVisible && !expanded) {
            remove(channel.id)
        }
        .onTapGesture(count: 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedID = expanded ? nil : channel.id
            }
            audibleID = channel.id
        }
        .onTapGesture {
            audibleID = channel.id
            showControls()
        }
    }

    private var topBar: some View {
        VStack {
            HStack(spacing: 12) {
                barButton(expandedID == nil ? "xmark" : "rectangle.grid.2x2",
                          label: expandedID == nil ? "Leave multiview" : "Back to all channels") {
                    if expandedID != nil {
                        withAnimation(.easeInOut(duration: 0.2)) { expandedID = nil }
                    } else {
                        store.close()
                    }
                }
                Text(expandedID == nil ? "Tap to hear · Double-tap for full screen" : "Double-tap to go back")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                if expandedID == nil {
                    Button {
                        picking = true
                    } label: {
                        Label("Add channel", systemImage: "plus")
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(.black.opacity(0.45), in: .capsule)
                    }
                    .disabled(store.isFull)
                    .opacity(store.isFull ? 0.4 : 1)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
        }
    }

    private func barButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.bold))
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.45), in: .circle)
                .contentShape(.circle)
        }
        .accessibilityLabel(label.localizedUI)
    }

    private func showControls() {
        withAnimation(.easeOut(duration: 0.2)) { controlsVisible = true }
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, !picking else { return }
            withAnimation(.easeOut(duration: 0.3)) { controlsVisible = false }
        }
    }

    // MARK: Engines

    private func remove(_ id: Int) {
        engines[id]?.stop()
        engines[id] = nil
        if expandedID == id { expandedID = nil }
        if audibleID == id { audibleID = store.channels.first(where: { $0.id != id })?.id }
        store.remove(id)
    }

    /// One engine per channel: new channels get one, removed channels lose theirs.
    private func syncEngines() async {
        let wanted = store.channels
        for (id, engine) in engines where !wanted.contains(where: { $0.id == id }) {
            engine.stop()
            engines[id] = nil
        }
        if audibleID == nil || !wanted.contains(where: { $0.id == audibleID }) { audibleID = wanted.first?.id }
        let client = settings.xtreamClient
        for (index, channel) in wanted.enumerated() where engines[channel.id] == nil {
            guard let engine = try? AetherEngine(),
                  let url = client.liveURL(for: channel, format: settings.prefs.liveFormat) else { continue }
            engine.logTag = "multiview-\(index + 1)"
            engine.deactivatesAudioSessionOnStop = true
            engine.volume = channel.id == audibleID ? 1 : 0
            engines[channel.id] = engine
            let options = LoadOptions(
                suppressDisplayCriteria: true,
                httpHeaders: client.requestHeaders,
                isLive: true,
                nativeRemoteHLS: false,
                preferredAudioLanguages: [settings.prefs.audioLanguage],
                // The engines share the audio session; only the first may publish Now Playing.
                sharedOutputRole: engines.count == 1 ? .primary : .secondary
            )
            try? AVAudioSession.sharedInstance().setActive(true)
            _ = try? await engine.load(url: url, options: options)
        }
        applyVolumes()
    }

    private func applyVolumes() {
        for (id, engine) in engines {
            engine.volume = id == audibleID ? 1 : 0
        }
    }
}

/// One picture: the video, the channel name with a speaker when it's the one you hear, and a
/// ✕ to take it out.
private struct MultiviewTile: View {
    let engine: AetherEngine?
    let channel: XtreamChannel
    let audible: Bool
    let expanded: Bool
    let showsControls: Bool
    let remove: () -> Void

    var body: some View {
        ZStack {
            Color.black
            if let engine {
                TileVideo(engine: engine)
            } else {
                ProgressView().tint(.white)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if !expanded {
                Label(channel.name, systemImage: audible ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.6), in: .capsule)
                    .padding(8)
            }
        }
        .overlay(alignment: .topTrailing) {
            if showsControls {
                Button(action: remove) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.black.opacity(0.6), in: .circle)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .accessibilityLabel("Remove \(channel.name)")
                .transition(.opacity)
            }
        }
        .clipShape(.rect(cornerRadius: expanded ? 0 : 12))
        .overlay {
            if !expanded {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white, lineWidth: audible ? 3 : 0)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(audible ? String(localized: "\(channel.name), playing sound") : channel.name)
    }
}

/// The video and its loading or error state, watching the engine.
private struct TileVideo: View {
    @ObservedObject var engine: AetherEngine

    private var error: String? {
        if case .error(let message) = engine.state { return message }
        return nil
    }

    var body: some View {
        ZStack {
            AetherPlayerSurface(engine: engine)
            if let error {
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.title3)
                    Text("Couldn't play this channel")
                        .font(.caption.weight(.bold))
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                    Text("Your provider may only allow one stream at a time.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(12)
            } else if !engine.hasFirstFrameReadyForDisplay || engine.isBuffering {
                ProgressView().tint(.white)
            }
        }
    }
}

/// Pick a channel to add: your favourites and recent channels, or search every group.
private struct MultiviewChannelPicker: View {
    let exclude: Set<Int>
    let pick: (XtreamChannel) -> Void
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var all: [XtreamChannel] = []
    @State private var results: [XtreamChannel] = []
    @State private var loading = true

    private var available: [XtreamChannel] {
        let prefs = settings.prefs
        return all.filter { channel in
            !exclude.contains(channel.id) && settings.isVisible(channel)
                && !ParentalLock.shared.isLocked(categoryID: channel.categoryID ?? "", prefs: prefs)
        }
    }

    private var favourites: [XtreamChannel] {
        available.filter { settings.prefs.favouriteChannelIDs.contains($0.id) }
    }

    private var recent: [XtreamChannel] {
        let byID = Dictionary(available.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return settings.prefs.recentChannelIDs.compactMap { byID[$0] }
    }

    var body: some View {
        NavigationStack {
            List {
                if !settings.xtream.isConfigured {
                    Text("Add your IPTV login in Settings › Connections first.").foregroundStyle(.secondary)
                } else if loading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if text.isEmpty {
                    if !favourites.isEmpty {
                        Section("Favourites") { rows(favourites) }
                    }
                    if !recent.isEmpty {
                        Section("Recently watched") { rows(recent) }
                    }
                    if favourites.isEmpty && recent.isEmpty {
                        Text("Search for a channel to add.").foregroundStyle(.secondary)
                    }
                } else if results.isEmpty {
                    Text("No channels match “\(text)”.").foregroundStyle(.secondary)
                } else {
                    rows(results)
                }
            }
            .navigationTitle("Add channel")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search channels")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .task {
            guard settings.xtream.isConfigured else { return }
            all = (try? await XtreamCache.shared.liveStreams(settings.xtreamClient)) ?? []
            loading = false
        }
        .task(id: text) {
            guard !text.isEmpty else { results = []; return }
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let found = await ChannelPlayback.search(text, settings: settings, parental: .shared)
            results = found.filter { !exclude.contains($0.id) }
        }
    }

    private func rows(_ channels: [XtreamChannel]) -> some View {
        ForEach(channels) { channel in
            Button {
                pick(channel)
            } label: {
                HStack(spacing: 12) {
                    ChannelLogo(channel: channel, width: 48, height: 28)
                    Text(channel.name).lineLimit(1)
                    Spacer()
                    Image(systemName: "plus.circle").foregroundStyle(.secondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }
}
