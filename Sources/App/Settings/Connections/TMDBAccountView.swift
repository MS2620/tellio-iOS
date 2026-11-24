import SwiftUI

/// Settings › Connections › TMDB: the catalogue and artwork token, language and region.
struct TMDBAccountView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var state: ConnectionState = .checking("Checking…")
    @State private var token = ""
    @State private var confirmingRemove = false

    var body: some View {
        SettingsPage("TMDB") {
            ConnectionHeader(icon: "film", state: state)

            SettingsGroup("Your token") {
                SettingsFieldRow(title: "API Read Access Token", icon: "key",
                                 prompt: settings.usingBuiltInTMDB ? "Using the built-in key" : "API Read Access Token",
                                 secure: true, text: $token)
                    .onSubmit(saveToken)
                if token != settings.ownTmdbToken {
                    Button(action: saveToken) {
                        SettingsRowLabel(title: "Save token", icon: "checkmark")
                    }
                    .buttonStyle(.plain)
                }
            }
            SettingsNote(!AppSettings.builtInTMDBToken.isEmpty
                ? "Tellio has a TMDB key built in, so there's nothing to set up. To use your own instead, get the long \"API Read Access Token\" from themoviedb.org › Settings › API."
                : "Free from themoviedb.org › Settings › API. Use the long \"API Read Access Token\", not the short API key.")

            SettingsGroup("Catalogue") {
                SettingsOptionRow(title: "Language", icon: "globe", selection: $settings.prefs.catalogueLanguage,
                                  options: LanguageOptions.catalogue)
                SettingsPickerRow(title: "Region", icon: "mappin.and.ellipse", selection: $settings.prefs.tmdbRegion,
                                  options: LanguageOptions.regions)
            }

            SettingsGroup {
                Button {
                    Task { await check() }
                } label: {
                    SettingsRowLabel(title: "Test connection", icon: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(settings.tmdbToken.isEmpty)
                if !settings.ownTmdbToken.isEmpty {
                    DestructiveRow(title: AppSettings.builtInTMDBToken.isEmpty ? "Remove token" : "Remove your token",
                                   icon: "trash") { confirmingRemove = true }
                }
            }
        }
        .onAppear { token = settings.ownTmdbToken }
        .task(id: settings.tmdbToken) { await check() }
        .confirmationDialog("Remove the TMDB token?", isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button("Remove token", role: .destructive) {
                settings.tmdbToken = ""
                token = ""
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(AppSettings.builtInTMDBToken.isEmpty
                 ? "Home, Browse and Search need it to show anything."
                 : "Tellio goes back to its built-in key.")
        }
    }

    private func saveToken() {
        settings.tmdbToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        token = settings.ownTmdbToken
    }

    private func check() async {
        state = .checking("Checking…")
        state = await ConnectionCheck.tmdb(settings)
    }
}
