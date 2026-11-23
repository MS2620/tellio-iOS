import SwiftUI

/// Settings › About › Send feedback. Opens a public GitHub issue through the feedback service;
/// the contact stays private on the server.
struct FeedbackView: View {
    @State private var kind: FeedbackService.Kind = .problem
    @State private var message = ""
    @State private var contact = ""
    @State private var includeDevice = true
    @State private var sending = false
    @State private var sent: FeedbackService.Sent?
    @State private var error: String?
    @FocusState private var messageFocused: Bool

    private var canSend: Bool {
        !sending && message.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    var body: some View {
        SettingsPage("Send feedback") {
            if let sent {
                SettingsGroup {
                    HStack(spacing: 14) {
                        Image(systemName: "checkmark")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(width: 36, height: 36)
                            .background(Theme.good, in: .circle)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Thanks, it's been sent").font(.headline)
                            Text("Reference #\(sent.number). Follow it at github.com/MS2620/tellio/issues")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                }
            } else {
                form
            }
        }
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button("Done") { messageFocused = false }
            }
        }
    }

    @ViewBuilder
    private var form: some View {
        Picker("Kind", selection: $kind) {
            ForEach(FeedbackService.Kind.allCases) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)

        SettingsGroup("Message") {
            TextField("What happened, or what you'd like", text: $message, axis: .vertical)
                .lineLimit(5...12)
                .focused($messageFocused)
                .padding(16)
        }

        SettingsGroup {
            SettingsFieldRow(title: "Email or GitHub name", icon: "at",
                             prompt: "Email or GitHub name (optional)", keyboard: .emailAddress, text: $contact)
            SettingsToggleRow(title: "Include device details", subtitle: FeedbackService.deviceDetails,
                              icon: "iphone", isOn: $includeDevice)
        }
        SettingsNote("Your contact is only for a reply; it's kept private and never posted. Feedback never includes your logins, server or channel names.")

        Button(action: send) {
            HStack(spacing: 8) {
                if sending {
                    ProgressView()
                } else {
                    Image(systemName: "paperplane.fill")
                }
                Text(sending ? "Sending…" : "Send")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .disabled(!canSend || !FeedbackService.isAvailable)

        if !FeedbackService.isAvailable {
            SettingsNote("Feedback isn't available in this build. You can open an issue at github.com/MS2620/tellio-iOS/issues instead.")
        } else if let error {
            Text(error)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func send() {
        guard canSend else { return }
        messageFocused = false
        sending = true
        error = nil
        Task {
            do {
                sent = try await FeedbackService.send(
                    kind: kind, message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                    contact: contact.trimmingCharacters(in: .whitespacesAndNewlines),
                    includeDevice: includeDevice)
            } catch {
                self.error = error.localizedDescription
            }
            sending = false
        }
    }
}

/// Open-source software built into Tellio, with each one's licence text.
/// AetherEngine's licence asks apps that ship it to show these.
struct Acknowledgement: Identifiable {
    let name: String
    let detail: String
    let licence: String
    /// The file in Resources/Licenses, without "License-" and ".txt".
    let file: String
    /// Its key in the build's library versions (from Package.resolved), if it has its own package.
    var versionKey: String? = nil
    var source: String? = nil

    var id: String { file }

    var version: String? {
        versionKey.flatMap { Acknowledgement.versions[$0] }
    }

    var text: String {
        guard let url = Bundle.module.url(forResource: "License-\(file)", withExtension: "txt",
                                          subdirectory: "Licenses"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "The licence text is missing from this build."
        }
        return text
    }

    /// "aetherengine=7.73.0,ffmpegbuild=3.15.0,…", filled in by the build from Package.resolved.
    static let versions: [String: String] = {
        let raw = Bundle.main.object(forInfoDictionaryKey: "LibraryVersions") as? String ?? ""
        var result: [String: String] = [:]
        for pair in raw.split(separator: ",") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2, !parts[1].isEmpty { result[parts[0]] = parts[1] }
        }
        return result
    }()

    static let all: [Acknowledgement] = [
        Acknowledgement(name: "AetherEngine", detail: "Video player engine",
                        licence: "LGPL-3.0 + App Store exception", file: "AetherEngine",
                        versionKey: "aetherengine", source: "github.com/superuser404notfound/AetherEngine"),
        Acknowledgement(name: "FFmpeg", detail: "Video and audio decoding", licence: "LGPL-2.1+",
                        file: "FFmpeg", versionKey: "ffmpegbuild",
                        source: "github.com/superuser404notfound/FFmpegBuild"),
        Acknowledgement(name: "dav1d", detail: "AV1 decoding", licence: "BSD-2-Clause", file: "dav1d",
                        versionKey: "ffmpegbuild", source: "github.com/superuser404notfound/FFmpegBuild"),
        Acknowledgement(name: "zimg", detail: "Scaling", licence: "WTFPL", file: "zimg",
                        versionKey: "ffmpegbuild", source: "github.com/superuser404notfound/FFmpegBuild"),
        Acknowledgement(name: "libzvbi", detail: "Teletext subtitles", licence: "LGPL-2.1 · MIT", file: "libzvbi",
                        versionKey: "ffmpegbuild", source: "github.com/superuser404notfound/FFmpegBuild"),
        Acknowledgement(name: "libdovi", detail: "© quietvoid and contributors", licence: "MIT", file: "libdovi",
                        versionKey: "libdovi", source: "github.com/quietvoid/dovi_tool"),
        Acknowledgement(name: "Anime4K", detail: "© 2019-2021 bloc97", licence: "MIT", file: "Anime4K",
                        source: "github.com/bloc97/Anime4K"),
        Acknowledgement(name: "Sentry", detail: "Crash reports · © 2015 Sentry", licence: "MIT", file: "Sentry",
                        versionKey: "sentry-cocoa", source: "github.com/getsentry/sentry-cocoa"),
    ]
}

/// Settings › About › Acknowledgements.
struct AcknowledgementsView: View {
    var body: some View {
        SettingsPage("Acknowledgements") {
            SettingsGroup("Data") {
                // TMDB asks for this credit.
                SettingsRowLabel(title: "TMDB",
                                 subtitle: "Film and TV information and artwork. This product uses the TMDB API but is not endorsed or certified by TMDB.",
                                 icon: "film")
            }

            SettingsGroup("Software") {
                ForEach(Acknowledgement.all) { item in
                    SettingsLink(title: item.version.map { "\(item.name) \($0)" } ?? item.name,
                                 subtitle: item.detail, icon: "doc.text", value: item.licence) {
                        LicenceTextView(item: item)
                    }
                }
            }
            SettingsNote(sourceNote)
        }
    }

    private var sourceNote: String {
        let engine = Acknowledgement.versions["aetherengine"].map { " (\($0))" } ?? ""
        let ffmpeg = Acknowledgement.versions["ffmpegbuild"].map { " (\($0))" } ?? ""
        return "Tap one to read its licence. Source code: github.com/superuser404notfound/AetherEngine\(engine) and /FFmpegBuild\(ffmpeg)."
    }
}

/// One licence's full text.
private struct LicenceTextView: View {
    let item: Acknowledgement

    var body: some View {
        SettingsPage(item.name) {
            VStack(alignment: .leading, spacing: 4) {
                Text([item.licence, item.version.map { "version \($0)" }].compactMap { $0 }.joined(separator: " · "))
                if let source = item.source {
                    Text("Source: \(source)")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            SettingsGroup {
                Text(item.text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
    }
}
