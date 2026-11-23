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
@MainActor
enum SystemPlayer {
    /// Lets sound play with the silent switch on, over AirPlay and in picture in picture.
    static func configureAudio() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    }

    static func present(_ request: PlaybackRequest) {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              var top = scene.keyWindow?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }

        let options: [String: Any]? = request.httpHeaders.isEmpty
            ? nil : ["AVURLAssetHTTPHeaderFieldsKey": request.httpHeaders]
        let item = AVPlayerItem(asset: AVURLAsset(url: request.url, options: options))
        item.externalMetadata = metadata(for: request)
        let player = AVPlayer(playerItem: item)

        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.modalPresentationStyle = .fullScreen
        try? AVAudioSession.sharedInstance().setActive(true)
        top.present(controller, animated: true) { player.play() }
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
