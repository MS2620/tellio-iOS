import SwiftUI

/// A programme picked in the guide (or a channel with nothing listed).
struct GuideSelection: Equatable {
    let channel: XtreamChannel
    let entry: XtreamEPGEntry?
}

/// One block in a guide row: a programme, or a gap between listings.
private struct GuideSegment: Identifiable {
    let id: String
    let entry: XtreamEPGEntry?
    let title: String
    let width: CGFloat
    let isGap: Bool
    let onNow: Bool
}

/// The TV guide: a time ruler along the top, channel logos down the left (both stay put while
/// scrolling) and each channel's programmes laid along the timeline.
struct GuideGrid<Menu: View>: View {
    let channels: [XtreamChannel]
    let epg: [Int: [XtreamEPGEntry]]
    let now: Date
    let showsGuide: Bool
    /// Channel numbers next to the names, when that's turned on.
    var showsNumbers = false
    /// Points per minute: 4 on iPhone (120 per half hour), more on iPad.
    var scale: CGFloat = 4
    @Binding var selection: GuideSelection?
    let isReminded: (Int, Date) -> Bool
    @ViewBuilder let menu: (XtreamChannel) -> Menu

    @State private var offset: CGPoint = .zero

    /// The guide builds rows lazily, but very large groups are still capped.
    static var rowLimit: Int { 200 }
    private static var hours: Int { 6 }
    private static var rowHeight: CGFloat { 60 }
    private static var rulerHeight: CGFloat { 30 }

    private var windowStart: Date {
        let seconds = now.timeIntervalSince1970
        return Date(timeIntervalSince1970: (seconds / 1800).rounded(.down) * 1800)
    }

    /// Logo and name of each channel; wider on iPad.
    private var channelColumn: CGFloat { scale > 5 ? 180 : 116 }

    private var windowEnd: Date { windowStart.addingTimeInterval(TimeInterval(Self.hours) * 3600) }
    private var gridWidth: CGFloat { CGFloat(Self.hours * 60) * scale }

    private var rows: [XtreamChannel] { Array(channels.prefix(Self.rowLimit)) }

    var body: some View {
        VStack(spacing: 0) {
            ruler
            // The channel column sits outside the scrolling grid and follows its vertical
            // scroll, like the ruler follows its horizontal scroll, so it never scrolls away.
            HStack(alignment: .top, spacing: 0) {
                channelColumnView
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(rows) { channel in
                            row(channel)
                        }
                    }
                    .overlay(alignment: .topLeading) { nowLine }
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(for: CGPoint.self) { geometry in
                    CGPoint(x: geometry.contentOffset.x + geometry.contentInsets.leading,
                            y: geometry.contentOffset.y + geometry.contentInsets.top)
                } action: { _, new in
                    offset = new
                }
            }
        }
    }

    /// Drawn in an overlay so its full height (every channel) doesn't stretch the layout;
    /// only the part beside the visible rows shows.
    private var channelColumnView: some View {
        Color.clear
            .frame(width: channelColumn)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .top) {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { channel in
                        GuideChannelCell(channel: channel, number: number(channel))
                            .frame(width: channelColumn - 6, height: Self.rowHeight - 4)
                            .background(.white.opacity(0.08), in: .rect(cornerRadius: 10))
                            .frame(height: Self.rowHeight)
                            .contentShape(.rect)
                            .contextMenu { menu(channel) }
                    }
                }
                .frame(width: channelColumn)
                .fixedSize(horizontal: false, vertical: true)
                .offset(y: -offset.y)
            }
            .clipped()
    }

    // MARK: - Pieces

    /// Half-hour marks, moved with the grid's horizontal scroll.
    private var ruler: some View {
        let marks = stride(from: 0, to: Self.hours * 2, by: 1).map { windowStart.addingTimeInterval(TimeInterval($0) * 1800) }
        // In an overlay, so its full width (six hours) doesn't stretch the layout.
        return Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: Self.rulerHeight)
            .overlay(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(marks, id: \.self) { mark in
                        Text(DayFormat.time(mark))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30 * scale, alignment: .leading)
                    }
                }
                .fixedSize()
                .offset(x: channelColumn + 4 - offset.x)
            }
            .clipped()
            .accessibilityHidden(true)
    }

    private var nowLine: some View {
        let x = CGFloat(now.timeIntervalSince(windowStart) / 60) * scale
        return Rectangle()
            .fill(.white)
            .frame(width: 2)
            .frame(maxHeight: .infinity)
            .offset(x: x)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func row(_ channel: XtreamChannel) -> some View {
        HStack(spacing: 0) {
            ForEach(segments(for: channel)) { segment in
                if segment.isGap {
                    Color.clear.frame(width: segment.width)
                } else {
                    block(segment, channel: channel)
                }
            }
        }
        .frame(height: Self.rowHeight)
        .contextMenu { menu(channel) }
    }

    private func number(_ channel: XtreamChannel) -> Int? {
        showsNumbers ? channel.number : nil
    }

    private func block(_ segment: GuideSegment, channel: XtreamChannel) -> some View {
        let selected = selection?.channel.id == channel.id && selection?.entry == segment.entry
        let reminded = segment.entry?.start.map { isReminded(channel.id, $0) } ?? false
        return Button {
            selection = GuideSelection(channel: channel, entry: segment.entry)
        } label: {
            HStack(spacing: 4) {
                if reminded {
                    Image(systemName: "bell.fill").font(.caption2).accessibilityLabel(Text("Reminder set"))
                }
                Text(segment.title)
                    .font(.footnote.weight(.bold))
                    .lineLimit(2)
            }
            .padding(.horizontal, 8)
            .frame(width: max(segment.width - 4, 4), height: Self.rowHeight - 4, alignment: .leading)
            .foregroundStyle(selected ? Theme.ink : .primary)
            .background(selected ? Color.white : .white.opacity(segment.onNow ? 0.22 : 0.1),
                        in: .rect(cornerRadius: 10))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .frame(width: segment.width, alignment: .leading)
        .accessibilityLabel(accessibilityText(segment, channel: channel))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func accessibilityText(_ segment: GuideSegment, channel: XtreamChannel) -> String {
        guard let entry = segment.entry, let start = entry.start, let end = entry.end else {
            return "\(channel.name), \(segment.title)"
        }
        return String(localized: "\(channel.name), \(segment.title), \(DayFormat.time(start)) to \(DayFormat.time(end))")
    }

    /// Lays a channel's listings along the timeline, filling holes with gaps (as on the Apple TV).
    private func segments(for channel: XtreamChannel) -> [GuideSegment] {
        let start = windowStart
        let end = windowEnd
        let listings = (epg[channel.id] ?? [])
            .filter { entry in
                guard let begins = entry.start, let ends = entry.end else { return false }
                return ends > start && begins < end
            }
            .sorted { ($0.start ?? .distantPast) < ($1.start ?? .distantPast) }

        var result: [GuideSegment] = []
        var cursor = start
        for entry in listings {
            guard let begins = entry.start, let ends = entry.end else { continue }
            let from = max(begins, cursor)
            let to = min(ends, end)
            // Skips listings that overlap one already placed.
            guard to > from else { continue }
            if from > cursor {
                result.append(GuideSegment(id: "gap\(result.count)", entry: nil, title: "",
                                           width: CGFloat(from.timeIntervalSince(cursor) / 60) * scale,
                                           isGap: true, onNow: false))
            }
            result.append(GuideSegment(id: "\(Int(begins.timeIntervalSince1970))|\(result.count)", entry: entry,
                                       title: entry.title.isEmpty ? "No information" : entry.title,
                                       width: CGFloat(to.timeIntervalSince(from) / 60) * scale,
                                       isGap: false, onNow: begins <= now && now < ends))
            cursor = to
        }
        if !result.contains(where: { !$0.isGap }) {
            // No listings: one block across the window, still selectable to watch.
            let waiting = epg[channel.id] == nil && showsGuide
            return [GuideSegment(id: "none", entry: nil, title: waiting ? "Loading guide…" : "No information",
                                 width: gridWidth, isGap: false, onNow: false)]
        }
        return result
    }
}

/// The fixed left column of a guide row: the logo with the name under it, or just the name
/// when there's no logo (initials alone can't tell channels apart).
private struct GuideChannelCell: View {
    let channel: XtreamChannel
    let number: Int?

    private var name: String {
        number.map { "\($0) \(channel.name)" } ?? channel.name
    }

    var body: some View {
        Group {
            if channel.icon != nil {
                VStack(alignment: .leading, spacing: 3) {
                    ChannelLogo(channel: channel, width: 44, height: 26)
                    Text(name)
                        .font(.caption2.weight(.bold))
                        .lineLimit(1)
                }
            } else {
                Text(name)
                    .font(.caption.weight(.bold))
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
    }
}
