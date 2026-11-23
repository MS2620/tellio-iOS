import SwiftUI

/// Settings › Connections › Trakt: sign in with a device code, what to sync, sync now, sign out.
struct TraktAccountView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var trakt = TraktSync.shared
    @Environment(\.openURL) private var openURL

    @State private var code: TraktDeviceCode?
    @State private var codeStarted = Date()
    @State private var signInMessage: String?
    @State private var confirmingSignOut = false
    @State private var copied = false

    private var state: ConnectionState {
        if let error = trakt.lastError { return .problem(error) }
        if trakt.isSignedIn { return .good("Signed in" + (trakt.username.map { " as \($0)" } ?? "")) }
        if code != nil { return .checking("Waiting for you to approve…") }
        return .off(trakt.hasApp ? "Not signed in" : "Add a Trakt Client ID first")
    }

    var body: some View {
        SettingsPage("Trakt") {
            ConnectionHeader(icon: "checkmark.seal", state: state)

            if let code, !trakt.isSignedIn {
                codePanel(code)
            }

            if trakt.isSignedIn {
                SettingsGroup("Account") {
                    Button {
                        confirmingSignOut = true
                    } label: {
                        SettingsRowLabel(title: trakt.username ?? "Your account", icon: "person.crop.circle",
                                         value: "Sign out")
                    }
                    .buttonStyle(.plain)
                    Button {
                        Task { await trakt.sync() }
                    } label: {
                        SettingsRowLabel(title: trakt.syncing ? "Syncing…" : "Sync now",
                                         subtitle: trakt.lastSync.map {
                                             "Last synced " + $0.formatted(.relative(presentation: .named))
                                         },
                                         icon: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.plain)
                    .disabled(trakt.syncing)
                }

                SettingsGroup("What to sync") {
                    SettingsToggleRow(title: "Progress & Continue Watching", icon: "play.circle",
                                      isOn: $settings.prefs.traktProgress)
                    SettingsToggleRow(title: "Watched history", icon: "checkmark.circle",
                                      isOn: $settings.prefs.traktHistory)
                    SettingsToggleRow(title: "Watchlist ↔ My List", icon: "plus.circle",
                                      isOn: $settings.prefs.traktWatchlist)
                    SettingsToggleRow(title: "Scrobble while watching", icon: "dot.radiowaves.left.and.right",
                                      isOn: $settings.prefs.traktScrobble)
                }
                SettingsNote("Syncs when Tellio opens and every 10 minutes. Scrobbling shows \u{201C}Watching now\u{201D} on your Trakt profile and marks things watched at 80%.")
            } else if code == nil {
                Button {
                    Task { await startSignIn() }
                } label: {
                    Text("Sign in to Trakt")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.glassProminent)
                .disabled(!trakt.hasApp)
                SettingsNote(signInMessage ?? (trakt.hasApp
                    ? "Sign in with your Trakt account. No Trakt app or keys to set up."
                    : "This copy of Tellio has no Trakt app built in. Add your own below to sign in."))
            }

            SettingsGroup {
                SettingsLink(title: "Use your own Trakt app", icon: "gearshape",
                             value: trakt.usingOwnApp ? "Your own" : (trakt.hasBuiltInApp ? "Built in" : "Set up")) {
                    TraktOwnAppView()
                }
            }
        }
        .confirmationDialog("Sign out of Trakt?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { trakt.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Progress and ticks already on this device stay. Nothing is deleted on Trakt.")
        }
        .task(id: code?.deviceCode) { await pollLoop() }
    }

    /// The code to approve, with buttons to open the Trakt page and copy the code.
    private func codePanel(_ code: TraktDeviceCode) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Go to \(code.verificationUrl.replacingOccurrences(of: "https://", with: "")) and enter this code")
                .font(.headline)
            HStack(spacing: 6) {
                ForEach(Array(code.userCode.enumerated()), id: \.offset) { _, character in
                    Text(String(character))
                        .font(.title2.weight(.heavy).monospaced())
                        .foregroundStyle(Theme.ink)
                        .frame(width: 34, height: 46)
                        .background(.white, in: .rect(cornerRadius: 8))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Code \(code.userCode.map(String.init).joined(separator: " "))")

            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = code.userCode
                    copied = true
                    if let url = URL(string: code.verificationUrl) { openURL(url) }
                } label: {
                    Label("Copy code and open", systemImage: "safari")
                }
                .buttonStyle(.glassProminent)
                Button {
                    UIPasteboard.general.string = code.userCode
                    copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.glass)
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let left = max(0, Int(codeStarted.addingTimeInterval(TimeInterval(code.expiresIn))
                    .timeIntervalSince(context.date)))
                Text("Waiting for you to approve… code expires in \(left / 60):\(String(format: "%02d", left % 60))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button("Cancel", role: .cancel) { self.code = nil }
                .buttonStyle(.glass)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 24)
    }

    private func startSignIn() async {
        signInMessage = nil
        copied = false
        do {
            let fresh = try await trakt.startSignIn()
            codeStarted = Date()
            code = fresh
        } catch {
            signInMessage = "Couldn't start sign-in: \(error.localizedDescription). Check the client ID."
        }
    }

    private func pollLoop() async {
        guard let code else { return }
        var interval = max(code.interval, 5)
        let deadline = codeStarted.addingTimeInterval(TimeInterval(code.expiresIn))
        while !Task.isCancelled, Date() < deadline {
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled else { return }
            switch await trakt.poll(code) {
            case .approved:
                self.code = nil
                return
            case .pending:
                continue
            case .slowDown:
                interval += 5
            case .expired:
                self.code = nil
                signInMessage = "The code expired. Sign in again."
                return
            case .denied:
                self.code = nil
                signInMessage = "Sign-in was declined on Trakt."
                return
            case .failed(let message):
                self.code = nil
                signInMessage = message
                return
            }
        }
        if !Task.isCancelled, self.code != nil {
            self.code = nil
            signInMessage = "The code expired. Sign in again."
        }
    }
}

/// Settings › Connections › Trakt › Use your own Trakt app: swaps the built-in Client ID for yours.
struct TraktOwnAppView: View {
    @ObservedObject private var trakt = TraktSync.shared
    @State private var clientID = ""
    @State private var clientSecret = ""

    var body: some View {
        SettingsPage("Your own Trakt app") {
            SettingsGroup {
                SettingsFieldRow(title: "Client ID", icon: "key",
                                 prompt: trakt.hasBuiltInApp ? "Using the built-in app" : "Client ID",
                                 text: $clientID)
                SettingsFieldRow(title: "Client secret", icon: "lock", prompt: "Older apps only", secure: true,
                                 text: $clientSecret)
                if clientID != trakt.clientID || clientSecret != trakt.clientSecret {
                    Button {
                        trakt.clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
                        trakt.clientSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
                    } label: {
                        SettingsRowLabel(title: "Save", icon: "checkmark")
                    }
                    .buttonStyle(.plain)
                }
                if trakt.usingOwnApp && trakt.hasBuiltInApp {
                    Button {
                        trakt.clientID = ""
                        trakt.clientSecret = ""
                        clientID = ""
                        clientSecret = ""
                    } label: {
                        SettingsRowLabel(title: "Go back to the built-in app", icon: "arrow.uturn.backward")
                    }
                    .buttonStyle(.plain)
                }
            }
            SettingsNote("On trakt.tv go to Settings › Your API Apps › New Application, give it any name and use urn:ietf:wg:oauth:2.0:oob as the redirect URI. New apps only have a Client ID; a secret is only needed for older apps. After changing the app, sign in to Trakt again.")
        }
        .onAppear {
            clientID = trakt.clientID
            clientSecret = trakt.clientSecret
        }
    }
}
