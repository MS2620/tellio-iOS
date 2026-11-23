import AVKit
import SwiftUI

/// What to play. Mirrors the Apple TV app's PlaybackRequest so the stage 4 player can take over.
struct PlaybackRequest: Identifiable {
    let id = UUID()
    var url: URL
    var title: String?
    var subtitle: String? = nil
    var isLive = false
    var httpHeaders: [String: String] = [:]
    /// For live TV: the channel list it was opened from, for zapping later.
    var live: LiveContext? = nil
}

struct LiveContext {
    var channels: [XtreamChannel]
    var index: Int
    var channel: XtreamChannel { channels[index] }
}

/// For now, playback uses Apple's full-screen player (AirPlay, picture in picture, rotation).
/// Stage 4 replaces it with Tellio's own player with channel zapping.
///
/// Only one stream plays at a time: closing the player, or opening another channel, stops the
/// stream straight away so the provider frees the connection (many allow only one).
@MainActor
enum SystemPlayer {
    private static var current: PlayerController?

    /// Lets sound play with the silent switch on, over AirPlay and in picture in picture.
    static func configureAudio() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    }

    static func present(_ request: PlaybackRequest) {
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
        top.present(controller, animated: true) { player.play() }
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

    fileprivate static func topController() -> UIViewController? {
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
