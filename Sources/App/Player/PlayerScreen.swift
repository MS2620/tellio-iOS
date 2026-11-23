import AetherEngine
import AVFoundation
import MediaPlayer
import SwiftUI

/// Tellio's player on iPhone and iPad, on AetherEngine like the Apple TV (MKV, HEVC, surround,
/// every subtitle format).
///
/// Tap to show or hide the controls. Films and episodes: double-tap the left or right side to
/// skip back or forward, drag the bar to seek, resume where you left off. Live TV: previous
/// and next channel, or swipe up and down on the picture. Pinch to fill the screen.
struct PlayerScreen: View {
    @ObservedObject var session: PlayerSession
    @ObservedObject var engine: AetherEngine
    @ObservedObject private var clock: PlaybackClock
    let close: () -> Void

    @StateObject private var pip = PictureInPicture()
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?
    @State private var fillScreen = false
    @State private var scrubbing: Double?
    @State private var loadError: String?
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?
    @State private var epg: [XtreamEPGEntry] = []
    @State private var lastRetune: Date?
    @State private var startedPlaying = false

    init(session: PlayerSession, engine: AetherEngine, close: @escaping () -> Void) {
        self.session = session
        self.engine = engine
        self._clock = ObservedObject(wrappedValue: engine.clock)
        self.close = close
    }

    private var request: PlaybackRequest? { session.request }
    private var settings: AppSettings? { session.settings }
    private var prefs: Preferences { settings?.prefs ?? Preferences() }
    private var isLive: Bool { request?.isLive ?? false }

    private var errorMessage: String? {
        if let loadError { return loadError }
        if case .error(let message) = engine.state { return message }
        return nil
    }

    private var isLoading: Bool {
        errorMessage == nil && (!engine.hasFirstFrameReadyForDisplay || engine.isBuffering)
    }

    private var nowProgramme: XtreamEPGEntry? {
        let now = Date()
        return epg.first { ($0.start ?? .distantFuture) <= now && now < ($0.end ?? .distantPast) }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AetherPlayerSurface(engine: engine)
                .ignoresSafeArea()

            SubtitleOverlay(cues: engine.subtitleCues, time: clock.sourceTime,
                            fontSize: prefs.subtitleSize.points * 0.48)
                .ignoresSafeArea()

            gestureLayer

            if isLoading && !pip.isActive {
                ProgressView().controlSize(.large).tint(.white)
            }

            if let errorMessage {
                errorCard(errorMessage)
            } else if controlsVisible {
                controls.transition(.opacity)
            }

            if let toast {
                Text(toast)
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.6), in: .capsule)
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(controlsVisible ? .automatic : .hidden)
        .task(id: request?.id) { await load() }
        .task(id: request?.id) { await progressLoop() }
        .task(id: request?.live?.channel.id) { await epgLoop() }
        .onAppear {
            pip.onClosed = { finish() }
            scheduleHide()
        }
        .onChange(of: engine.state) { old, state in
            // Trakt's "Watching now" follows play and pause.
            if state == .paused { scrobble("pause"); saveProgress() }
            if state == .playing && old != .playing && old != .seeking { scrobble("start") }
            if state == .ended {
                if let watch = request?.watch { WatchHistory.shared.setWatched(true, context: watch) }
                finish()
            }
        }
        .onChange(of: engine.hasFirstFrameReadyForDisplay) { _, ready in
            if ready { pip.rebuild(for: engine) }
        }
        .onReceive(engine.$softwarePiPSource) { _ in pip.rebuild(for: engine) }
        .onReceive(engine.liveSourceReset.receive(on: DispatchQueue.main)) { _ in retune() }
    }

    // MARK: - Gestures

    private var gestureLayer: some View {
        GeometryReader { geo in
            Color.clear
                .contentShape(.rect)
                .onTapGesture(count: 2) { location in
                    guard !isLive else { return }
                    skip(location.x < geo.size.width / 2 ? -Double(prefs.seekBackSeconds) : Double(prefs.seekForwardSeconds))
                }
                .onTapGesture { toggleControls() }
                .gesture(
                    DragGesture(minimumDistance: 40).onEnded { value in
                        guard isLive, abs(value.translation.height) > abs(value.translation.width) * 1.5 else { return }
                        zap(by: value.translation.height < 0 ? 1 : -1)
                    }
                )
                .simultaneousGesture(
                    MagnifyGesture().onEnded { value in
                        let fill = value.magnification > 1
                        if fill != fillScreen { setFill(fill) }
                    }
                )
        }
        .ignoresSafeArea()
    }

    // MARK: - Controls

    private var controls: some View {
        ZStack {
            LinearGradient(colors: [.black.opacity(0.65), .clear, .clear, .black.opacity(0.75)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                Spacer()
                centreButtons
                Spacer()
                bottomBar
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .foregroundStyle(.white)
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: 12) {
            roundButton("xmark", label: "Close") { finish() }
            VStack(alignment: .leading, spacing: 2) {
                Text(request?.title ?? "")
                    .font(.headline.weight(.heavy))
                    .lineLimit(1)
                if let line = isLive ? nowProgramme?.title : request?.subtitle, !line.isEmpty {
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .padding(.top, 4)
            Spacer(minLength: 8)
            tracksMenu
            if pip.isPossible {
                roundButton("pip.enter", label: "Picture in picture") { pip.toggle() }
            }
            AirPlayButton()
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.35), in: .circle)
        }
    }

    private var centreButtons: some View {
        HStack(spacing: 44) {
            if isLive {
                if (request?.live?.channels.count ?? 0) > 1 {
                    bigButton("chevron.up", size: 26, label: "Previous channel") { zap(by: -1) }
                }
            } else {
                bigButton("gobackward.\(prefs.seekBackSeconds)", size: 30, label: "Back \(prefs.seekBackSeconds) seconds") {
                    skip(-Double(prefs.seekBackSeconds))
                }
                .disabled(!engine.canSeek)
            }

            bigButton(engine.state == .paused ? "play.fill" : "pause.fill", size: 44,
                      label: engine.state == .paused ? "Play" : "Pause") {
                engine.togglePlayPause()
                scheduleHide()
            }

            if isLive {
                if (request?.live?.channels.count ?? 0) > 1 {
                    bigButton("chevron.down", size: 26, label: "Next channel") { zap(by: 1) }
                }
            } else {
                bigButton("goforward.\(prefs.seekForwardSeconds)", size: 30, label: "Forward \(prefs.seekForwardSeconds) seconds") {
                    skip(Double(prefs.seekForwardSeconds))
                }
                .disabled(!engine.canSeek)
            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if isLive {
            HStack(spacing: 10) {
                Text("LIVE")
                    .font(.caption.weight(.heavy))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.live, in: .capsule)
                if let live = request?.live {
                    Text("\(live.index + 1) of \(live.channels.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                aspectButton
            }
        } else {
            VStack(spacing: 4) {
                Slider(value: Binding(get: { scrubbing ?? clock.currentTime },
                                      set: { scrubbing = $0 }),
                       in: 0...max(engine.duration, 1)) { editing in
                    if editing {
                        hideTask?.cancel()
                    } else if let target = scrubbing {
                        Task {
                            await engine.seek(to: target)
                            scrubbing = nil
                        }
                        scheduleHide()
                    }
                }
                .tint(.white)
                .disabled(!engine.canSeek || engine.duration <= 0)
                HStack {
                    Text(Self.time(scrubbing ?? clock.currentTime))
                    Spacer()
                    aspectButton
                    Spacer()
                    Text("-" + Self.time(max(engine.duration - (scrubbing ?? clock.currentTime), 0)))
                }
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private var aspectButton: some View {
        Button {
            setFill(!fillScreen)
        } label: {
            Image(systemName: fillScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .font(.subheadline.weight(.bold))
                .frame(width: 36, height: 30)
                .contentShape(.rect)
        }
        .accessibilityLabel(fillScreen ? "Fit to screen" : "Fill screen")
    }

    private var tracksMenu: some View {
        Menu {
            if !engine.audioTracks.isEmpty {
                Section("Audio") {
                    ForEach(engine.audioTracks) { track in
                        Button {
                            engine.selectAudioTrack(index: track.id)
                        } label: {
                            if track.id == engine.activeAudioTrackIndex {
                                Label(Self.label(track), systemImage: "checkmark")
                            } else {
                                Text(Self.label(track))
                            }
                        }
                    }
                }
            }
            Section("Subtitles") {
                Button {
                    engine.clearSubtitle()
                } label: {
                    if engine.activeSubtitleTrackIndex == nil {
                        Label("Off", systemImage: "checkmark")
                    } else {
                        Text("Off")
                    }
                }
                ForEach(engine.subtitleTracks) { track in
                    Button {
                        engine.selectSubtitleTrack(index: track.id)
                    } label: {
                        if track.id == engine.activeSubtitleTrackIndex {
                            Label(Self.label(track), systemImage: "checkmark")
                        } else {
                            Text(Self.label(track))
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "captions.bubble")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.35), in: .circle)
        }
        .accessibilityLabel("Audio and subtitles")
        .simultaneousGesture(TapGesture().onEnded { hideTask?.cancel() })
    }

    private func roundButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.bold))
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.35), in: .circle)
                .contentShape(.circle)
        }
        .accessibilityLabel(label)
    }

    private func bigButton(_ icon: String, size: CGFloat, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .bold))
                .frame(width: size + 34, height: size + 34)
                .contentShape(.circle)
        }
        .accessibilityLabel(label)
    }

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(Theme.warning)
            Text("This stream couldn't be played")
                .font(.headline.weight(.heavy))
            Text(message)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(4)
            HStack(spacing: 12) {
                Button("Close") { finish() }
                    .buttonStyle(.glass)
                Button("Try again") { reload() }
                    .buttonStyle(.glassProminent)
                    .tint(.white)
                    .foregroundStyle(Theme.ink)
            }
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: 380)
        .glassPanel(cornerRadius: 26)
        .padding(24)
    }

    // MARK: - Playback

    private func load() async {
        guard let request else { return }
        loadError = nil
        startedPlaying = false
        let prefs = self.prefs
        var shaping = AudioShaping()
        if prefs.dialogueBoost { shaping.dialogueGainDB = 6 }
        if prefs.nightMode { shaping.compressor = .night }
        let subtitleLanguages = prefs.autoSubtitles ? [prefs.subtitleLanguage] : []

        let options: LoadOptions
        if request.isLive {
            options = LoadOptions(
                httpHeaders: request.httpHeaders,
                isLive: true,
                dvrWindowSeconds: prefs.timeshiftMinutes > 0 ? Double(prefs.timeshiftMinutes * 60) : nil,
                liveJoinProfile: prefs.channelSwitching == .fast ? .fastZap : .standard,
                // The engine reads HLS itself: Apple's HLS player can play the sound but no
                // picture on some channels (HEVC or interlaced broadcasts).
                nativeRemoteHLS: false,
                preferredAudioLanguages: [prefs.audioLanguage],
                preferredSubtitleLanguages: subtitleLanguages,
                audioShaping: shaping
            )
        } else {
            options = LoadOptions(
                httpHeaders: request.httpHeaders,
                preferredAudioLanguages: [prefs.audioLanguage],
                preferredSubtitleLanguages: subtitleLanguages,
                audioShaping: shaping
            )
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: request.title ?? "Tellio",
            MPNowPlayingInfoPropertyMediaType: NSNumber(value: MPNowPlayingInfoMediaType.video.rawValue),
            MPNowPlayingInfoPropertyIsLiveStream: NSNumber(value: request.isLive),
        ]
        if let line = request.subtitle, !line.isEmpty { info[MPMediaItemPropertyArtist] = line }
        engine.setNowPlayingInfo(info)

        do {
            try? AVAudioSession.sharedInstance().setActive(true)
            _ = try await engine.load(url: request.url, startPosition: request.startPosition, options: options)
            engine.videoGravity = fillScreen ? .resizeAspectFill : .resizeAspect
        } catch is CancellationError {
            // A newer load (another channel) or closing the player replaced this one.
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func reload() {
        guard var copy = session.request else { return }
        copy.id = UUID()
        if !copy.isLive, engine.duration > 0, clock.currentTime > 0 { copy.startPosition = clock.currentTime }
        session.request = copy
    }

    /// The engine asks for a fresh load when a live session can't be revived on its own.
    private func retune() {
        guard isLive else { return }
        if let lastRetune, Date().timeIntervalSince(lastRetune) < 10 { return }
        lastRetune = Date()
        reload()
    }

    private func zap(by step: Int) {
        guard let live = request?.live, let settings, live.channels.count > 1 else { return }
        let index = (live.index + step + live.channels.count) % live.channels.count
        let channel = live.channels[index]
        guard let url = settings.xtreamClient.liveURL(for: channel, format: settings.prefs.liveFormat) else { return }
        var recent = settings.prefs.recentChannelIDs.filter { $0 != channel.id }
        recent.insert(channel.id, at: 0)
        settings.prefs.recentChannelIDs = Array(recent.prefix(20))
        session.request = PlaybackRequest(url: url, title: channel.name, isLive: true,
                                          httpHeaders: request?.httpHeaders ?? [:],
                                          live: LiveContext(channels: live.channels, index: index))
        showToast(channel.name)
    }

    private func skip(_ seconds: Double) {
        guard engine.canSeek else { return }
        let target = min(max(0, clock.currentTime + seconds), max(engine.duration - 1, 0))
        Task { await engine.seek(to: target) }
        showToast(seconds < 0 ? "−\(Int(-seconds)) s" : "+\(Int(seconds)) s")
    }

    private func setFill(_ fill: Bool) {
        fillScreen = fill
        engine.videoGravity = fill ? .resizeAspectFill : .resizeAspect
        showToast(fill ? "Fill screen" : "Fit to screen")
    }

    /// Saves progress, tells Trakt, stops the stream (freeing the provider connection) and closes.
    private func finish() {
        hideTask?.cancel()
        toastTask?.cancel()
        saveProgress()
        scrobble("stop")
        pip.tearDown()
        engine.stop()
        session.request = nil
        close()
    }

    private func progressLoop() async {
        guard request?.watch != nil, !isLive else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            saveProgress()
        }
    }

    private func epgLoop() async {
        epg = []
        guard let channel = request?.live?.channel, let settings, settings.prefs.showEPG else { return }
        while !Task.isCancelled {
            if let entries = try? await settings.xtreamClient.shortEPG(streamID: channel.id, limit: 4) {
                epg = entries
            }
            try? await Task.sleep(for: .seconds(60))
        }
    }

    private func saveProgress() {
        guard let watch = request?.watch, !isLive, engine.duration > 0,
              engine.hasFirstFrameReadyForDisplay, clock.currentTime > 0 else { return }
        WatchHistory.shared.record(watch, position: clock.currentTime, duration: engine.duration)
    }

    private func scrobble(_ action: String) {
        guard let watch = request?.watch, !isLive, engine.duration > 0 else { return }
        TraktSync.shared.scrobble(action, context: watch, progress: clock.currentTime / engine.duration * 100)
    }

    // MARK: - Overlay timing

    private func toggleControls() {
        withAnimation(.easeOut(duration: 0.2)) { controlsVisible.toggle() }
        if controlsVisible { scheduleHide() }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, engine.state == .playing, scrubbing == nil else { return }
            withAnimation(.easeOut(duration: 0.3)) { controlsVisible = false }
        }
    }

    private func showToast(_ text: String) {
        toastTask?.cancel()
        withAnimation { toast = text }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            withAnimation { toast = nil }
        }
    }

    // MARK: - Formatting

    /// "1:04:12" or "21:14".
    static func time(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = max(Int(seconds), 0)
        let h = total / 3600, m = total % 3600 / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    /// "English · 5.1" or the track's own name.
    static func label(_ track: TrackInfo) -> String {
        var parts: [String] = []
        let name = track.name.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            parts.append(name)
        } else if let code = track.language, let language = Locale.current.localizedString(forLanguageCode: code) {
            parts.append(language)
        } else {
            parts.append("Track \(track.id + 1)")
        }
        switch track.channels {
        case 6: parts.append("5.1")
        case 8: parts.append("7.1")
        case 2: parts.append("Stereo")
        default: break
        }
        return parts.joined(separator: " · ")
    }
}
