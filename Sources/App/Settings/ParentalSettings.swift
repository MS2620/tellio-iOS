import SwiftUI

/// The 4-digit keypad: checks the PIN, or asks for a new one twice.
struct PINEntryView: View {
    enum Mode { case verify, create }
    let mode: Mode
    let onSuccess: () -> Void
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var lock = ParentalLock.shared
    @State private var digits = ""
    @State private var firstEntry: String?
    @State private var message: String?
    @State private var shake: CGFloat = 0
    @State private var confirmingReset = false

    private static let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"]

    private var heading: String {
        switch mode {
        case .verify: return "Enter PIN"
        case .create: return firstEntry == nil ? "Choose a 4-digit PIN" : "Enter it again"
        }
    }

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.font(.body.weight(.semibold))
            }
            Spacer(minLength: 0)
            Text(heading).font(.title2.weight(.heavy))
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < digits.count ? Color.white : Color.white.opacity(0.25))
                        .frame(width: 16, height: 16)
                }
            }
            .offset(x: shake)
            .accessibilityElement()
            .accessibilityLabel("\(digits.count) of 4 digits entered")
            Text(message ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.danger)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(78), spacing: 22), count: 3), spacing: 16) {
                ForEach(Self.keys, id: \.self) { key in
                    if key.isEmpty {
                        Color.clear.frame(width: 78, height: 78)
                    } else {
                        Button {
                            press(key)
                        } label: {
                            Group {
                                if key == "⌫" {
                                    Image(systemName: "delete.left")
                                } else {
                                    Text(key)
                                }
                            }
                            .font(.title.weight(.semibold))
                            .frame(width: 78, height: 78)
                            .background(key == "⌫" ? .clear : .white.opacity(0.12), in: .circle)
                            .contentShape(.circle)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(key == "⌫" ? "Delete" : key)
                    }
                }
            }
            if mode == .verify {
                Button("Forgot PIN?") { confirmingReset = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .appBackground()
        .confirmationDialog("Reset parental controls?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Delete all connections and reset", role: .destructive) {
                settings.deleteAllConnections()
                settings.prefs.parentalControlsOn = false
                lock.setPIN(nil)
                dismiss()
                onSuccess()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Without the PIN, the only way back in is to remove your IPTV login, TMDB key and addons. You can add them again afterwards.")
        }
    }

    private func press(_ key: String) {
        message = nil
        if key == "⌫" {
            if !digits.isEmpty { digits.removeLast() }
            return
        }
        guard digits.count < 4 else { return }
        digits += key
        guard digits.count == 4 else { return }
        switch mode {
        case .verify:
            if lock.matches(digits) {
                lock.unlock(minutes: settings.prefs.unlockMinutes)
                dismiss()
                onSuccess()
            } else {
                wrong("Wrong PIN")
            }
        case .create:
            if let first = firstEntry {
                if first == digits {
                    lock.setPIN(digits)
                    lock.unlock(minutes: settings.prefs.unlockMinutes)
                    dismiss()
                    onSuccess()
                } else {
                    firstEntry = nil
                    wrong("The PINs didn't match. Start again.")
                }
            } else {
                firstEntry = digits
                digits = ""
            }
        }
    }

    private func wrong(_ text: String) {
        message = text
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        Task { @MainActor in
            for offset in [-14.0, 14, -9, 9, -4, 0] {
                withAnimation(.linear(duration: 0.05)) { shake = offset }
                try? await Task.sleep(for: .milliseconds(50))
            }
            digits = ""
        }
    }
}

extension View {
    /// Shows the PIN keypad while `isPresented` is true.
    func pinPrompt(_ isPresented: Binding<Bool>, mode: PINEntryView.Mode = .verify,
                   onSuccess: @escaping () -> Void) -> some View {
        sheet(isPresented: isPresented) {
            PINEntryView(mode: mode, onSuccess: onSuccess)
                .presentationDetents([.large])
        }
    }
}

/// Settings › Parental controls: the PIN, how long it stays unlocked, and which Live TV
/// groups and addons need it. Needs the PIN to open while controls are on.
struct ParentalControlsView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var lock = ParentalLock.shared
    @State private var categories: [XtreamCategory] = []
    @State private var askingPIN = false
    @State private var creatingPIN = false
    @State private var unlockedHere = false

    private var locked: Bool { lock.settingsNeedPIN(prefs: settings.prefs) && !unlockedHere }

    var body: some View {
        SettingsPage("Parental controls") {
            if locked {
                SettingsGroup {
                    SettingsActionRow(title: "Enter PIN to change these settings", icon: "lock.fill") {
                        askingPIN = true
                    }
                }
            } else {
                SettingsGroup("PIN") {
                    SettingsToggleRow(title: "Parental PIN", subtitle: "Asks for the PIN to open locked items",
                                      icon: "key", isOn: Binding(
                                          get: { settings.prefs.parentalControlsOn },
                                          set: { on in
                                              if on {
                                                  creatingPIN = true
                                              } else {
                                                  settings.prefs.parentalControlsOn = false
                                                  lock.setPIN(nil)
                                              }
                                          }))
                    if settings.prefs.parentalControlsOn {
                        SettingsActionRow(title: "Change PIN", icon: "pencil") { creatingPIN = true }
                        SettingsToggleRow(title: "Hide locked groups", icon: "eye.slash",
                                          isOn: $settings.prefs.hideLockedGroups)
                        SettingsOptionRow(title: "Stay unlocked for", icon: "timer",
                                          selection: $settings.prefs.unlockMinutes,
                                          options: [(5, "5 minutes"), (15, "15 minutes"), (30, "30 minutes"),
                                                    (60, "1 hour"), (240, "4 hours")])
                        SettingsActionRow(title: "Lock now", icon: "lock") {
                            lock.lockNow()
                            unlockedHere = false
                        }
                    }
                }
                SettingsNote("Locked groups and addons need the PIN. Once entered, everything stays unlocked for the time you choose, then locks again. The PIN is shared with the Apple TV through the backup.")

                SettingsGroup("Locked Live TV groups") {
                    if categories.isEmpty {
                        SettingsRowLabel(title: settings.xtream.isConfigured ? "Loading groups…" : "Add your IPTV login first",
                                         icon: "folder")
                    }
                    ForEach(categories, id: \.id) { category in
                        SettingsToggleRow(title: category.name,
                                          icon: settings.prefs.lockedCategoryIDs.contains(category.id) ? "lock.fill" : "folder",
                                          isOn: setBinding(\.lockedCategoryIDs, category.id))
                    }
                }

                SettingsGroup("Locked addons") {
                    if settings.addons.isEmpty {
                        SettingsRowLabel(title: "No addons", icon: "puzzlepiece")
                    }
                    ForEach(settings.addons) { addon in
                        SettingsToggleRow(title: addon.name, subtitle: "Its streams need the PIN",
                                          icon: settings.prefs.lockedAddonIDs.contains(addon.id) ? "lock.fill" : "puzzlepiece",
                                          isOn: setBinding(\.lockedAddonIDs, addon.id))
                    }
                }
            }
        }
        .onAppear {
            unlockedHere = lock.isUnlocked
            if locked { askingPIN = true }
        }
        .task(id: settings.xtream) {
            guard settings.xtream.isConfigured else { return }
            categories = (try? await XtreamCache.shared.liveCategories(settings.xtreamClient)) ?? []
        }
        .pinPrompt($askingPIN) { unlockedHere = true }
        .background {
            Color.clear.pinPrompt($creatingPIN, mode: .create) {
                settings.prefs.parentalControlsOn = true
                unlockedHere = true
            }
        }
    }

    /// A switch for whether an id is in one of the locked sets.
    private func setBinding(_ path: WritableKeyPath<Preferences, Set<String>>, _ id: String) -> Binding<Bool> {
        Binding(
            get: { settings.prefs[keyPath: path].contains(id) },
            set: { on in
                if on {
                    settings.prefs[keyPath: path].insert(id)
                } else {
                    settings.prefs[keyPath: path].remove(id)
                }
            })
    }
}
