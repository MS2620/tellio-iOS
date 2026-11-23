import SwiftUI

// Status checks and rows shared by the Connections screens. The checks match the Apple TV app's.

/// How a connection is doing, shown as a coloured dot and a short line.
enum ConnectionState: Equatable {
    case checking(String)
    case good(String)
    case problem(String)
    case off(String)

    var text: String {
        switch self {
        case .checking(let text), .good(let text), .problem(let text), .off(let text): return text
        }
    }

    var dot: Color {
        switch self {
        case .checking: return .white.opacity(0.4)
        case .good: return Theme.good
        case .problem: return Theme.warning
        case .off: return .white.opacity(0.25)
        }
    }
}

enum ConnectionCheck {
    static func iptv(_ account: XtreamAccount, userAgent: String) async -> (ConnectionState, XtreamAccountInfo?) {
        guard account.isConfigured else { return (.off("Not set up"), nil) }
        do {
            let info = try await XtreamClient(account: account, userAgent: userAgent).accountInfo()
            guard info.signedIn else { return (.problem("Login failed"), info) }
            var parts = [info.isActive ? "Online" : info.status]
            if let connections = info.connectionsText { parts.append(connections) }
            if let expires = info.expires {
                parts.append("expires " + expires.formatted(date: .abbreviated, time: .omitted))
            }
            let text = parts.joined(separator: " · ")
            return (info.isActive ? .good(text) : .problem(text), info)
        } catch {
            return (.problem("Can't reach the server"), nil)
        }
    }

    static func tmdb(_ settings: AppSettings) async -> ConnectionState {
        guard !settings.tmdbToken.isEmpty else { return .off("Not set up") }
        do {
            return try await settings.tmdb.validate() ? .good("Connected") : .problem("Token not accepted")
        } catch HTTPError.status(let code, _) where code == 401 {
            return .problem("Token not accepted")
        } catch {
            return .problem("Can't reach TMDB")
        }
    }

    static func addon(_ entry: AddonEntry) async -> (ConnectionState, AddonManifest?) {
        guard let url = URL(string: entry.manifestURL) else { return (.problem("Address isn't valid"), nil) }
        do {
            let manifest = try await StremioAddonClient(manifestURL: url).manifest()
            let kinds = (manifest.types ?? []).map(typeName).joined(separator: ", ")
            return (.good(kinds.isEmpty ? "Online" : "Online · " + kinds), manifest)
        } catch {
            return (.problem("Can't reach the addon"), nil)
        }
    }

    static func typeName(_ type: String) -> String {
        switch type {
        case "movie": return "Movies"
        case "series": return "Series"
        case "tv": return "TV"
        case "channel": return "Channels"
        default: return type.capitalized
        }
    }
}

/// A connection row: icon tile, name with an optional badge, status dot and line, a note on the right.
struct ConnectionRowLabel: View {
    let title: String
    let icon: String
    var state: ConnectionState? = nil
    var trailing: String? = nil
    var badge: String? = nil
    var showsChevron = true

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.16), in: .rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title).font(.body.weight(.semibold)).lineLimit(1)
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.heavy))
                            .tracking(0.5)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .foregroundStyle(Theme.ink)
                            .background(.white, in: .capsule)
                    }
                }
                if let state {
                    HStack(spacing: 6) {
                        Circle().fill(state.dot).frame(width: 8, height: 8)
                        Text(state.text).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing).foregroundStyle(.secondary).lineLimit(1)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 52)
        .contentShape(.rect)
    }
}

/// The top of an account screen: large icon, status dot and line.
struct ConnectionHeader: View {
    let icon: String
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 52, height: 52)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
            HStack(spacing: 8) {
                Circle().fill(state.dot).frame(width: 10, height: 10)
                Text(state.text).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }
}

/// A row with a menu of choices, e.g. the catalogue language.
struct SettingsPickerRow: View {
    let title: String
    let icon: String
    @Binding var selection: String
    let options: [Choice]

    var body: some View {
        HStack(spacing: 0) {
            SettingsRowLabel(title: title, icon: icon)
            Picker(title, selection: $selection) {
                ForEach(options) { option in
                    Text(option.name).tag(option.code)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .padding(.trailing, 6)
        }
    }
}

/// A button row in red, for removing things.
struct DestructiveRow: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            SettingsRowLabel(title: title, icon: icon)
                .foregroundStyle(Theme.danger)
        }
        .buttonStyle(.plain)
    }
}
