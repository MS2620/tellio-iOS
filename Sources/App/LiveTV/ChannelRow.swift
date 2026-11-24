import SwiftUI

/// A channel in the Live TV list: logo, name, what's on now with progress, and what's next.
struct ChannelRow: View {
    let channel: XtreamChannel
    var number: Int? = nil
    var favourite = false
    /// "UK | Sports FHD", shown in Favourites, Recent and folders where groups are mixed.
    var folderName: String? = nil
    let entries: [XtreamEPGEntry]?
    let now: Date
    let showsGuide: Bool

    var body: some View {
        let current = NowNext.current(entries, at: now)
        let next = NowNext.next(entries, at: now)
        HStack(spacing: 12) {
            ChannelLogo(channel: channel)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if let number { Text(verbatim: "\(number)").monospacedDigit() }
                    Text(channel.name).lineLimit(1)
                    if favourite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.primary)
                            .accessibilityLabel("Favourite")
                    }
                }
                .font(.footnote.weight(.bold))
                .foregroundStyle(.secondary)

                if showsGuide, let current {
                    Text(current.title)
                        .font(.body.weight(.bold))
                        .lineLimit(1)
                    ProgressView(value: NowNext.progress(current, at: now))
                        .progressViewStyle(.linear)
                        .tint(.white)
                        .accessibilityHidden(true)
                    if let next, let start = next.start {
                        Text("Next \(DayFormat.time(start)) · \(next.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text(folderName ?? (showsGuide && entries == nil ? String(localized: "Loading guide…") : String(localized: "No guide information")))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 64)
        .contentShape(.rect)
    }
}

/// The channel's logo on a light tile, or its initials when there's no logo.
struct ChannelLogo: View {
    let channel: XtreamChannel
    var width: CGFloat = 56
    var height: CGFloat = 36

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(0.9))
            if let icon = channel.icon, let url = URL(string: icon) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit().padding(4)
                    } else {
                        initials
                    }
                }
            } else {
                initials
            }
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }

    private var initials: some View {
        Text(Self.initials(channel.name))
            .font(.caption.weight(.black))
            .foregroundStyle(Theme.ink)
    }

    static func initials(_ name: String) -> String {
        let words = name.split { !$0.isLetter && !$0.isNumber }.prefix(2)
        return words.compactMap(\.first).map(String.init).joined().uppercased()
    }
}
