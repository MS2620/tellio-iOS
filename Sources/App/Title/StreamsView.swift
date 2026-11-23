import SwiftUI

/// A film or episode to find streams for. Mirrors the Apple TV's StreamTarget (that one lives
/// in a tvOS view file); keep the two in step.
struct StreamTarget: Identifiable, Hashable {
    let type: String   // "movie" or "series"
    let id: String     // addon id, e.g. "tt0903747:1:1"
    let title: String
    /// Episode line for the player, e.g. "S1E2 · Pilot".
    var subtitle: String? = nil
    /// "FILM · 2026" or "SEASON 1 · EPISODE 2".
    var kicker: String? = nil
    /// Episode name or year, under the title.
    var detail: String? = nil
    var posterURL: URL? = nil
    var backdropURL: URL? = nil
    /// Saves progress and offers to resume.
    var watch: WatchContext? = nil

    static func episode(item: TMDBItem, imdbID: String, season: Int, episode: Int, name: String?) -> StreamTarget {
        StreamTarget(type: "series", id: "\(imdbID):\(season):\(episode)", title: item.displayTitle,
                     subtitle: "S\(season)E\(episode) · \(name ?? "Episode \(episode)")",
                     kicker: "SEASON \(season) · EPISODE \(episode)", detail: name,
                     posterURL: item.posterURL, backdropURL: item.backdropURL,
                     watch: WatchContext(item: item, imdbID: imdbID, season: season, episode: episode,
                                         episodeName: name))
    }

    static func movie(item: TMDBItem, imdbID: String) -> StreamTarget {
        StreamTarget(type: "movie", id: imdbID, title: item.displayTitle, subtitle: item.year,
                     kicker: ["FILM", item.year].compactMap { $0 }.joined(separator: " · "), detail: nil,
                     posterURL: item.posterURL, backdropURL: item.backdropURL,
                     watch: WatchContext(item: item, imdbID: imdbID))
    }
}

/// Quality groups for the stream filters.
enum StreamQuality: Int, CaseIterable, Hashable {
    case uhd = 2160, fhd = 1080, hd = 720, sd = 480, unknown = 0

    init(_ resolution: Int) {
        switch resolution {
        case 1440...: self = .uhd
        case 1080..<1440: self = .fhd
        case 720..<1080: self = .hd
        case 1..<720: self = .sd
        default: self = .unknown
        }
    }

    var label: String {
        switch self {
        case .uhd: return "4K"
        case .fhd: return "1080p"
        case .hd: return "720p"
        case .sd: return "SD"
        case .unknown: return "Other"
        }
    }

    var badge: String {
        switch self {
        case .uhd: return "4K"
        case .fhd: return "FHD"
        case .hd: return "HD"
        case .sd: return "SD"
        case .unknown: return "WEB"
        }
    }
}

/// Asks every addon for streams, then lists them best quality first (or in addon order, per
/// Settings), with quality filters. Tapping one plays it, offering to resume a started title.
struct StreamsView: View {
    let target: StreamTarget
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var parental = ParentalLock.shared

    @State private var results: [FoundStream] = []
    @State private var loading = true
    @State private var notes: [String] = []
    @State private var filter: StreamQuality?
    @State private var lockedAddons = 0
    @State private var askingPIN = false
    @State private var pin = ""
    @State private var wrongPIN = false
    @State private var resumeChoice: FoundStream?

    private var counts: [StreamQuality: Int] {
        Dictionary(grouping: results) { StreamQuality($0.stream.resolution) }.mapValues(\.count)
    }

    private var shown: [FoundStream] {
        guard let filter else { return results }
        return results.filter { StreamQuality($0.stream.resolution) == filter }
    }

    private var resumeEntry: WatchEntry? {
        guard let watch = target.watch, let entry = WatchHistory.shared.entry(for: watch), entry.isResumable else {
            return nil
        }
        return entry
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if !results.isEmpty { filters }
                content
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .appBackground()
        .navigationTitle("Streams")
        .navigationBarTitleDisplayMode(.inline)
        .task { await search() }
        .confirmationDialog(resumeEntry.map { "You stopped at \(Self.time($0.position))" } ?? "",
                            isPresented: Binding(get: { resumeChoice != nil }, set: { if !$0 { resumeChoice = nil } }),
                            titleVisibility: .visible, presenting: resumeChoice) { result in
            Button("Resume from \(Self.time(resumeEntry?.position ?? 0))") {
                start(result, at: resumeEntry?.position)
            }
            Button("Start from the beginning") { start(result, at: nil) }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Enter PIN", isPresented: $askingPIN) {
            SecureField("PIN", text: $pin).keyboardType(.numberPad)
            Button("Unlock", action: unlock)
            Button("Cancel", role: .cancel) { pin = "" }
        } message: {
            Text(wrongPIN ? "That PIN isn't right. Try again." : "Some addons are locked by parental controls.")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Artwork(url: target.posterURL)
                .frame(width: 78, height: 117)
                .clipShape(.rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 6) {
                if let kicker = target.kicker {
                    Text(kicker)
                        .font(.caption.weight(.heavy))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                }
                Text(target.title)
                    .font(.title2.weight(.black))
                    .lineLimit(2)
                if let detail = target.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let entry = resumeEntry {
                    Text("\(entry.timeLeftLabel) · resume offered when you pick a stream")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All · \(results.count)", selected: filter == nil) { filter = nil }
                ForEach(StreamQuality.allCases.filter { (counts[$0] ?? 0) > 0 }, id: \.self) { quality in
                    chip("\(quality.label) · \(counts[quality] ?? 0)", selected: filter == quality) { filter = quality }
                }
            }
        }
        .scrollClipDisabled()
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? Theme.ink : .white)
                .background(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.12)), in: .capsule)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        if loading {
            ProgressView("Searching \(settings.addons.count) addon\(settings.addons.count == 1 ? "" : "s")…")
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if results.isEmpty {
            Text(settings.addons.isEmpty
                 ? "No addons yet. Add one in Settings › Connections."
                 : "No playable streams found.")
                .font(.headline)
                .padding(.top, 20)
        } else {
            let addonCount = Set(results.map(\.addonName)).count
            Text("\(results.count) STREAM\(results.count == 1 ? "" : "S") FROM \(addonCount) ADDON\(addonCount == 1 ? "" : "S")"
                 + (settings.prefs.streamSort == .quality ? " · BEST FIRST" : ""))
                .font(.caption.weight(.heavy))
                .foregroundStyle(.secondary)
        }
        ForEach(notes, id: \.self) { note in
            Text(note).font(.footnote).foregroundStyle(.secondary)
        }
        if lockedAddons > 0 && !loading {
            Button("\(lockedAddons) locked addon\(lockedAddons == 1 ? "" : "s") · Enter PIN", systemImage: "lock.fill") {
                askingPIN = true
            }
            .buttonStyle(.glass)
        }
        LazyVStack(spacing: 10) {
            ForEach(shown) { result in
                Button {
                    choose(result)
                } label: {
                    StreamCard(result: result)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private func choose(_ result: FoundStream) {
        if resumeEntry != nil {
            resumeChoice = result
        } else {
            start(result, at: nil)
        }
    }

    private func start(_ result: FoundStream, at position: Double?) {
        guard let url = result.stream.playableURL else { return }
        SystemPlayer.present(PlaybackRequest(url: url, title: target.title, subtitle: target.subtitle,
                                             watch: target.watch, startPosition: position))
    }

    private func unlock() {
        if parental.matches(pin) {
            parental.unlock(minutes: settings.prefs.unlockMinutes)
            pin = ""
            wrongPIN = false
            Task { await search() }
        } else {
            pin = ""
            wrongPIN = true
            DispatchQueue.main.async { askingPIN = true }
        }
    }

    private func search() async {
        loading = true
        notes = []
        let prefs = settings.prefs
        lockedAddons = settings.addons.filter { parental.isLocked(addon: $0, prefs: prefs) }.count
        var found: [FoundStream] = []
        var failures: [String] = []
        let type = target.type
        let id = target.id

        await withTaskGroup(of: (String, [StremioStream]?).self) { group in
            for addon in settings.addons {
                guard let url = URL(string: addon.manifestURL), !parental.isLocked(addon: addon, prefs: prefs) else { continue }
                let name = addon.name
                group.addTask {
                    (name, try? await StremioAddonClient(manifestURL: url).streams(type: type, id: id))
                }
            }
            for await (name, streams) in group {
                if let streams {
                    found += streams.map { FoundStream(addonName: name, stream: $0) }
                } else {
                    failures.append(name)
                }
            }
        }

        // Only direct links can be played; torrent-only results are left out.
        let playable = found.filter { $0.stream.playableURL != nil }
        let skipped = found.count - playable.count
        results = arrange(playable)
        loading = false
        if !failures.isEmpty { notes.append("Couldn't reach: " + failures.sorted().joined(separator: ", ")) }
        if skipped > 0 { notes.append("\(skipped) torrent-only result\(skipped == 1 ? "" : "s") hidden.") }

        if prefs.autoPlayFirstStream, let first = results.first {
            choose(first)
        }
    }

    /// Applies the resolution limit and sort order from Settings (shared with the Apple TV).
    private func arrange(_ streams: [FoundStream]) -> [FoundStream] {
        let prefs = settings.prefs
        var list = streams
        if prefs.maxResolution != .any {
            // Unknown resolution (0) is kept rather than hidden.
            list = list.filter { $0.stream.resolution <= prefs.maxResolution.maxLines }
        }
        if prefs.streamSort == .quality {
            // Stable: keeps addon order within the same resolution.
            list = list.enumerated()
                .sorted { a, b in
                    a.element.stream.resolution != b.element.stream.resolution
                        ? a.element.stream.resolution > b.element.stream.resolution
                        : a.offset < b.offset
                }
                .map(\.element)
        }
        return list
    }

    /// "1:04:12" or "21:14".
    static func time(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600, m = total % 3600 / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

/// One stream: quality badge, the addon's details as tags, source line and addon name.
private struct StreamCard: View {
    let result: FoundStream

    /// The addon's text, one entry per line, without decorative emoji.
    private var lines: [String] {
        let text = [result.stream.title, result.stream.description].compactMap { $0 }.first ?? ""
        return text
            .split(whereSeparator: \.isNewline)
            .map { line in
                String(String.UnicodeScalarView(line.unicodeScalars.filter { scalar in
                    !(scalar.properties.isEmojiPresentation || (scalar.properties.isEmoji && scalar.value > 0x2000))
                        && scalar.value != 0xFE0F
                }))
                .trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
    }

    private var tags: [String] {
        guard let first = lines.first else { return [] }
        return first.components(separatedBy: CharacterSet(charactersIn: "·|•"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .map { String($0.prefix(24)) }
    }

    private var source: String {
        lines.count > 1 ? lines[1] : result.stream.headline
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(StreamQuality(result.stream.resolution).badge)
                .font(.subheadline.weight(.heavy))
                .frame(width: 56, height: 40)
                .background(.white.opacity(0.14), in: .rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 5) {
                if !tags.isEmpty {
                    Text(tags.joined(separator: " · "))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(source)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(2)
                Text(result.addonName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "play.fill")
                .font(.body.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 18)
        .contentShape(.rect(cornerRadius: 18))
    }
}

extension View {
    /// The pages a title can lead to; added at the root of each tab's navigation stack.
    func titleDestinations() -> some View {
        navigationDestination(for: TMDBItem.self) { TitleView(item: $0) }
            .navigationDestination(for: StreamTarget.self) { StreamsView(target: $0) }
    }
}
