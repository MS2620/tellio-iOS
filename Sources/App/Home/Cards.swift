import SwiftUI

/// Artwork from a URL, with a soft placeholder (and the title) while it loads or if it's missing.
struct Artwork: View {
    let url: URL?
    var title: String? = nil

    var body: some View {
        // The image fills whatever frame it's given and is cropped to it; drawn in an overlay
        // so its own size can't stretch the layout (a wide backdrop widened the whole page).
        Color.clear
            .overlay {
                AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        ZStack(alignment: .bottomLeading) {
                            Rectangle().fill(.white.opacity(0.1))
                            if let title {
                                Text(title)
                                    .font(.footnote.weight(.heavy))
                                    .lineLimit(3)
                                    .padding(8)
                            }
                        }
                    }
                }
            }
            .clipped()
    }
}

/// A row title, like "Continue Watching", with an optional trailing link.
struct RailTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.title3.weight(.heavy))
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A titled, horizontally scrolling row.
struct Rail<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RailTitle(text: title)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    content
                }
                .padding(.horizontal, 20)
            }
            .scrollClipDisabled()
        }
    }
}

/// A poster with the title under it.
struct PosterCard: View {
    let item: TMDBItem
    var width: CGFloat = 112

    @ObservedObject private var history = WatchHistory.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Artwork(url: item.posterURL, title: item.displayTitle)
                .frame(width: width, height: width * 1.5)
                .clipShape(.rect(cornerRadius: 12))
                .overlay(alignment: .topTrailing) { WatchedBadge(item: item) }
            Text(item.displayTitle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: width, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A wide backdrop card with the title and year.
struct BackdropCard: View {
    let item: TMDBItem
    var width: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Artwork(url: item.backdropURL ?? item.posterURL, title: item.displayTitle)
                .frame(width: width, height: width * 9 / 16)
                .clipShape(.rect(cornerRadius: 12))
                .overlay(alignment: .topTrailing) { WatchedBadge(item: item) }
            Text(item.displayTitle)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .frame(width: width, alignment: .leading)
            Text([item.kind == .movie ? "Film" : "Series", item.year].compactMap { $0 }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A tick on titles you've watched.
private struct WatchedBadge: View {
    let item: TMDBItem
    @ObservedObject private var history = WatchHistory.shared

    var body: some View {
        if history.isWatched(item) {
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Theme.ink, .white)
                .padding(6)
                .accessibilityLabel("Watched")
        }
    }
}

/// My List and watched actions for a title's long-press menu.
struct TitleMenu: View {
    let item: TMDBItem
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Button(settings.isInMyList(item) ? "Remove from My List" : "Add to My List",
               systemImage: settings.isInMyList(item) ? "minus.circle" : "plus.circle") {
            settings.toggleMyList(item)
        }
        if item.kind == .movie, let entry = WatchHistory.shared.entry(item: item) {
            Button(entry.watched ? "Mark as unwatched" : "Mark as watched",
                   systemImage: entry.watched ? "eye.slash" : "checkmark.circle") {
                WatchHistory.shared.setWatched(!entry.watched, context: entry.context)
            }
        }
    }
}
