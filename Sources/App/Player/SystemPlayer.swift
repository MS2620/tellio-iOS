import AVKit
import SwiftUI

/// What to play. Mirrors the Apple TV app's PlaybackRequest so the stage 4 player can take over.
struct PlaybackRequest: Identifiable {
    /// A new id reloads the stream (Try again keeps the rest).
    var id = UUID()
    var url: URL
    var title: String?
    var subtitle: String? = nil
    var isLive = false
    var httpHeaders: [String: String] = [:]
    /// For live TV: the channel list it was opened from, for zapping later.
    var live: LiveContext? = nil
    /// A film or episode: progress is saved (Continue Watching) and Trakt told what's playing.
    var watch: WatchContext? = nil
    /// Where to start, in seconds, when resuming.
    var startPosition: Double? = nil
}

struct LiveContext {
    var channels: [XtreamChannel]
    var index: Int
    var channel: XtreamChannel { channels[index] }
}

/// Opens Tellio's player (PlayerScreen, on AetherEngine). Apple's player is only a fallback
/// for the unlikely case that the engine can't start.
///
/// Only one stream plays at a time: opening something while the player is up swaps the stream
/// in place, and closing the player stops it straight away so the provider frees the
/// connection (many allow only one).
@MainActor
enum SystemPlayer {
    private static var current: PlayerController?
    private static var screen: PlayerHostingController?

    static func present(_ request: PlaybackRequest) {
        let session = PlayerSession.shared
        guard let engine = session.engine else {
            presentSystemPlayer(request)
            return
        }
        if let screen, screen.presentingViewController != nil {
            session.request = request
            return
        }
        // One thing at a time: leave multiview (freeing its connections) before the player opens.
        if MultiviewStore.shared.isShowing {
            MultiviewStore.shared.close()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                present(request)
            }
            return
        }
        guard let top = topController() else { return }
        session.request = request
        let controller = PlayerHostingController(rootView: AnyView(
            PlayerScreen(session: session, engine: engine) {
                if let shown = screen {
                    screen = nil
                    shown.dismiss(animated: true)
                }
            }
        ))
        controller.modalPresentationStyle = .fullScreen
        screen = controller
        top.present(controller, animated: true)
    }

    /// Lets sound play with the silent switch on, over AirPlay and in picture in picture.
    static func configureAudio() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    }

    /// Apple's player, used only when AetherEngine can't start.
    private static func presentSystemPlayer(_ request: PlaybackRequest) {
        stop()
        guard let top = topController() else { return }

        let options: [String: Any]? = request.httpHeaders.isEmpty
            ? nil : ["AVURLAssetHTTPHeaderFieldsKey": request.httpHeaders]
        let item = AVPlayerItem(asset: AVURLAsset(url: request.url, options: options))
        item.externalMetadata = metadata(for: request)
        let player = AVPlayer(playerItem: item)

        let controller = PlayerController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.modalPresentationStyle = .fullScreen
        controller.onFinished = { [weak controller] in
            if let controller, current === controller { stop() }
        }
        current = controller
        try? AVAudioSession.sharedInstance().setActive(true)
        controller.track(request.isLive ? nil : request.watch, startAt: request.startPosition)
        top.present(controller, animated: true) {
            if (request.startPosition ?? 0) <= 0 { player.play() }
        }
    }

    /// Stops the stream and drops the player, closing its connection to the server.
    static func stop() {
        guard let controller = current else { return }
        current = nil
        controller.release()
        if controller.presentingViewController != nil {
            controller.dismiss(animated: false)
        }
    }

    static func topController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              var top = scene.keyWindow?.rootViewController else { return nil }
        while let presented = top.presentedViewController { top = presented }
        return top
    }

    private static func metadata(for request: PlaybackRequest) -> [AVMetadataItem] {
        var items: [AVMetadataItem] = []
        if let title = request.title { items.append(item(.commonIdentifierTitle, title)) }
        if let subtitle = request.subtitle { items.append(item(.iTunesMetadataTrackSubTitle, subtitle)) }
        return items
    }

    private static func item(_ identifier: AVMetadataIdentifier, _ value: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as NSString
        item.extendedLanguageTag = "und"
        return item
    }
}

/// The system player, told when it's closed so the stream can be stopped. Picture in picture
/// keeps playing after the full-screen player goes away, until it's closed too.
private final class PlayerController: AVPlayerViewController, AVPlayerViewControllerDelegate {
    var onFinished: (() -> Void)?
    private var inPictureInPicture = false
    private var watch: WatchContext?
    private var timeObserver: Any?
    private var observations: [NSKeyValueObservation] = []
    private var lastPlaying: Bool?

    /// Resumes at a position once the stream is ready, saves progress every 15 seconds, and
    /// tells Trakt when playback starts and pauses.
    func track(_ watch: WatchContext?, startAt: Double?) {
        guard let player else { return }
        self.watch = watch
        if let startAt, startAt > 0, let item = player.currentItem {
            observations.append(item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                guard item.status != .unknown else { return }
                DispatchQueue.main.async {
                    guard let self, let player = self.player else { return }
                    self.observations.removeAll()
                    self.observePlaying(player)
                    if item.status == .readyToPlay {
                        player.seek(to: CMTime(seconds: startAt, preferredTimescale: 600)) { _ in
                            DispatchQueue.main.async { player.play() }
                        }
                    } else {
                        player.play()
                    }
                }
            })
        } else {
            observePlaying(player)
        }
        guard watch != nil else { return }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 15, preferredTimescale: 1),
                                                      queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveProgress() }
        }
    }

    private func observePlaying(_ player: AVPlayer) {
        guard watch != nil else { return }
        observations.append(player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let playing = player.timeControlStatus == .playing
            let paused = player.timeControlStatus == .paused
            guard playing || paused else { return }
            DispatchQueue.main.async {
                guard let self, self.lastPlaying != playing else { return }
                self.lastPlaying = playing
                self.scrobble(playing ? "start" : "pause")
                if paused { self.saveProgress() }
            }
        })
    }

    private var position: (current: Double, duration: Double)? {
        guard let item = player?.currentItem else { return nil }
        let duration = item.duration.seconds
        let current = item.currentTime().seconds
        guard duration.isFinite, duration > 0, current.isFinite else { return nil }
        return (current, duration)
    }

    private func saveProgress() {
        guard let watch, let position, position.current > 0 else { return }
        WatchHistory.shared.record(watch, position: position.current, duration: position.duration)
    }

    private func scrobble(_ action: String) {
        guard let watch, let position else { return }
        TraktSync.shared.scrobble(action, context: watch, progress: position.current / position.duration * 100)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil, !inPictureInPicture {
            onFinished?()
        }
    }

    /// Pauses and removes the stream, which closes its connection.
    func release() {
        saveProgress()
        scrobble("stop")
        watch = nil
        observations.removeAll()
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        timeObserver = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }

    func playerViewControllerWillStartPictureInPicture(_ controller: AVPlayerViewController) {
        inPictureInPicture = true
    }

    func playerViewControllerDidStopPictureInPicture(_ controller: AVPlayerViewController) {
        inPictureInPicture = false
        // Closed from picture in picture without going back to full screen.
        if viewIfLoaded?.window == nil { onFinished?() }
    }

    func playerViewController(_ controller: AVPlayerViewController,
                              restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completion: @escaping (Bool) -> Void) {
        // Back to full screen from picture in picture.
        guard presentingViewController == nil, let top = SystemPlayer.topController() else {
            completion(true)
            return
        }
        top.present(self, animated: true) { completion(true) }
    }
}
