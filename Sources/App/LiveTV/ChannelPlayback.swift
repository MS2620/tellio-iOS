import Foundation

/// Plays a live channel from Live TV or Search, and adds it to Recent.
@MainActor
enum ChannelPlayback {
    static func play(_ channel: XtreamChannel, in list: [XtreamChannel], settings: AppSettings,
                     nowPlaying: String?) {
        let client = settings.xtreamClient
        guard let url = client.liveURL(for: channel, format: settings.prefs.liveFormat) else { return }
        // Newest first, 20 at most, as on the Apple TV.
        var recent = settings.prefs.recentChannelIDs.filter { $0 != channel.id }
        recent.insert(channel.id, at: 0)
        settings.prefs.recentChannelIDs = Array(recent.prefix(20))
        SystemPlayer.present(PlaybackRequest(
            url: url,
            title: channel.name,
            subtitle: nowPlaying,
            isLive: true,
            httpHeaders: client.requestHeaders,
            live: LiveContext(channels: list, index: list.firstIndex(of: channel) ?? 0)
        ))
    }

    /// Visible, unlocked channels whose name matches, from every group.
    static func search(_ text: String, settings: AppSettings, parental: ParentalLock,
                       limit: Int = 150) async -> [XtreamChannel] {
        guard settings.xtream.isConfigured else { return [] }
        let all = (try? await XtreamCache.shared.liveStreams(settings.xtreamClient)) ?? []
        let prefs = settings.prefs
        let found = all.filter { channel in
            settings.isVisible(channel)
                && !parental.isLocked(categoryID: channel.categoryID ?? "", prefs: prefs)
                && channel.name.localizedStandardContains(text)
        }
        return Array(found.prefix(limit))
    }
}
