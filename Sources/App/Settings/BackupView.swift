import SwiftUI

/// Settings › Backup & restore: back up to a code on your own server, or restore from one.
/// The backup is encrypted on the device with the code and server password (shared BackupService).
struct BackupView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var backup = BackupService.shared

    @State private var working = false
    @State private var newCode: String?
    @State private var message: String?

    var body: some View {
        SettingsPage("Backup & restore") {
            BackupServerGroup()

            SettingsGroup("Backup & restore") {
                Button {
                    Task { await runBackup() }
                } label: {
                    SettingsRowLabel(title: working ? "Backing up…" : "Back up to a code",
                                     subtitle: "Logins, addons, My List, teams, watch history, reminders, Trakt and settings",
                                     icon: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                .disabled(!backup.isConfigured || working)

                SettingsLink(title: "Restore from a code", icon: "square.and.arrow.down") {
                    RestoreView()
                }

                if let code = backup.lastCode, let date = backup.lastDate {
                    SettingsInfoRow(title: "Last backup", icon: "clock",
                                    value: "\(code) · \(date.formatted(.relative(presentation: .named)))")
                }
            }

            if let newCode {
                BackupCodeCard(code: newCode)
            }
            if let message {
                SettingsNote(message)
            }
        }
    }

    private func runBackup() async {
        working = true
        defer { working = false }
        message = nil
        do {
            newCode = try await backup.backUp(settings: settings)
        } catch {
            message = "Backup failed: \(error.localizedDescription)"
        }
    }
}

/// Server address, password and a connection check. Shared by backing up and restoring.
struct BackupServerGroup: View {
    @ObservedObject private var backup = BackupService.shared
    @State private var serverOK: Bool?
    @State private var checking = false

    var body: some View {
        SettingsGroup("Your backup server") {
            SettingsFieldRow(title: "Server", icon: "server.rack", prompt: "https://backup.example.com",
                             keyboard: .URL, text: Binding(
                                 get: { backup.serverURL },
                                 set: { backup.serverURL = $0; serverOK = nil }))
            SettingsFieldRow(title: "Password", icon: "lock", secure: true, text: Binding(
                get: { backup.password },
                set: { backup.password = $0; serverOK = nil }))
            if backup.isConfigured {
                Button {
                    Task {
                        checking = true
                        serverOK = await backup.checkServer()
                        checking = false
                    }
                } label: {
                    SettingsRowLabel(title: "Check connection", icon: "checkmark.circle",
                                     value: checking ? "Checking…" : serverOK.map { $0 ? "Working" : "Not reachable" })
                }
                .buttonStyle(.plain)
            }
        }
        SettingsNote("The same backup server and password as on your Apple TV.")
    }
}

/// Restores everything from a backup code: the screen behind "Bring your Apple TV setup".
struct RestoreView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var backup = BackupService.shared

    @State private var code = ""
    @State private var confirming = false
    @State private var working = false
    @State private var message: String?

    var body: some View {
        SettingsPage("Restore") {
            SettingsNote("On the Apple TV: Settings › Backup & restore › Back up to a code. Then enter the server, its password and the code here.")

            BackupServerGroup()

            SettingsGroup("Backup code") {
                SettingsFieldRow(title: "Code", icon: "number", prompt: "8 characters", text: $code)
                    .textInputAutocapitalization(.characters)
            }

            Button {
                confirming = true
            } label: {
                Text(working ? "Restoring…" : "Restore")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.glassProminent)
            .disabled(!canRestore || working)

            if let message {
                SettingsNote(message)
            }
        }
        .confirmationDialog("Restore this backup?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Replace this device's settings", role: .destructive) {
                Task { await runRestore() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your logins, addons, lists, history and settings here are replaced by the backup's.")
        }
    }

    private var cleanedCode: String {
        code.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    private var canRestore: Bool {
        backup.isConfigured && cleanedCode.count == 8
    }

    private func runRestore() async {
        working = true
        defer { working = false }
        message = nil
        do {
            try await backup.restore(code: cleanedCode, settings: settings)
            message = "Restored. Everything from the backup is in place."
        } catch {
            message = "Restore failed: \(error.localizedDescription)"
        }
    }
}

/// The new code after a backup, in large white tiles.
private struct BackupCodeCard: View {
    let code: String

    var body: some View {
        VStack(spacing: 14) {
            Text("BACKUP READY · KEPT FOR 30 DAYS")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(Array(code.enumerated()), id: \.offset) { index, character in
                    if index == 4 {
                        Text("·").font(.title2.weight(.heavy)).foregroundStyle(.secondary)
                    }
                    Text(String(character))
                        .font(.title2.weight(.heavy).monospaced())
                        .foregroundStyle(Theme.ink)
                        .frame(width: 32, height: 44)
                        .background(.white, in: .rect(cornerRadius: 8))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Backup code \(code.map(String.init).joined(separator: " "))")
            Text("On another device: Settings › Backup & restore › Restore from a code, and enter this.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassPanel(cornerRadius: 24)
    }
}
