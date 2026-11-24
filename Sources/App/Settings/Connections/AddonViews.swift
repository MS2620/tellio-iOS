import SwiftUI

/// Settings › Connections › an addon: what it provides, whether it's used and for what, its
/// place in the order, rename, remove.
struct AddonDetailView: View {
    let addonID: String
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var state: ConnectionState = .checking("Checking…")
    @State private var manifest: AddonManifest?
    @State private var confirmingRemove = false
    @State private var renaming = false
    @State private var newName = ""

    private var addon: AddonEntry? { settings.addons.first { $0.id == addonID } }
    private var index: Int? { settings.addons.firstIndex { $0.id == addonID } }

    private var address: String {
        guard let addon, let url = URL(string: addon.manifestURL) else { return "—" }
        return url.host ?? addon.manifestURL
    }

    var body: some View {
        SettingsPage(addon?.name ?? "Addon") {
            ConnectionHeader(icon: "puzzlepiece.extension", state: state)

            SettingsGroup("About") {
                SettingsInfoRow(title: "Version", icon: "number", value: manifest?.version ?? "—")
                SettingsInfoRow(title: "Provides", icon: "square.stack",
                                value: (manifest?.types ?? []).map(ConnectionCheck.typeName)
                                    .joined(separator: ", ").nonEmpty ?? "—")
                SettingsInfoRow(title: "Address", icon: "globe", value: address)
            }
            if let description = manifest?.description, !description.isEmpty {
                SettingsNote(description)
            }

            if let addon, let index {
                SettingsGroup("Use") {
                    SettingsToggleRow(title: "Use this addon", icon: "power", isOn: enabledBinding(index: index))
                    if addon.enabled {
                        ForEach(AddonUse.allCases) { use in
                            SettingsToggleRow(title: use.label, icon: Self.icon(use), isOn: usedBinding(use, index: index))
                        }
                        if addon.chosenUses != nil {
                            Button {
                                settings.addons[index].chosenUses = nil
                            } label: {
                                SettingsRowLabel(title: "Back to automatic", icon: "wand.and.stars")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                SettingsNote(addon.enabled ? usesNote(addon)
                             : String(localized: "Switched off: it isn't searched for anything, and keeps its settings for when you switch it back on."))
            }

            SettingsGroup("Order") {
                Button { move(by: -1) } label: {
                    SettingsRowLabel(title: "Move up", icon: "arrow.up",
                                     value: index.map { String(localized: "\($0 + 1) of \(settings.addons.count)") })
                }
                .buttonStyle(.plain)
                .disabled((index ?? 0) == 0)
                Button { move(by: 1) } label: {
                    SettingsRowLabel(title: "Move down", icon: "arrow.down")
                }
                .buttonStyle(.plain)
                .disabled((index ?? 0) >= settings.addons.count - 1)
            }
            SettingsNote("When streams are sorted by addon order, addons higher in the list come first.")

            SettingsGroup {
                Button {
                    newName = addon?.name ?? ""
                    renaming = true
                } label: {
                    SettingsRowLabel(title: "Rename", icon: "pencil")
                }
                .buttonStyle(.plain)
                DestructiveRow(title: "Remove addon", icon: "trash") { confirmingRemove = true }
            }
        }
        .task {
            guard let addon else { return }
            let result = await ConnectionCheck.addon(addon)
            state = result.0
            manifest = result.1
            if let manifest = result.1 { settings.noteManifest(manifest, for: addon.id) }
        }
        .alert("Rename addon", isPresented: $renaming) {
            TextField("Name", text: $newName)
            Button("Save") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let index, !name.isEmpty else { return }
                settings.addons[index].name = name
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Remove this addon?", isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button("Remove addon", role: .destructive) {
                settings.addons.removeAll { $0.id == addonID }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func move(by offset: Int) {
        guard let from = index else { return }
        let to = from + offset
        guard settings.addons.indices.contains(to) else { return }
        var list = settings.addons
        list.swapAt(from, to)
        settings.addons = list
    }

    static func icon(_ use: AddonUse) -> String {
        switch use {
        case .movies: return "film"
        case .series: return "tv"
        case .live: return "sportscourt"
        }
    }

    private func enabledBinding(index: Int) -> Binding<Bool> {
        Binding(get: { settings.addons.indices.contains(index) && settings.addons[index].enabled }, set: { on in
            guard settings.addons.indices.contains(index) else { return }
            settings.addons[index].enabled = on
        })
    }

    /// Ticking or unticking a kind turns the automatic choice into the user's own.
    private func usedBinding(_ use: AddonUse, index: Int) -> Binding<Bool> {
        Binding(get: { settings.addons.indices.contains(index) && settings.addons[index].uses.contains(use) }, set: { on in
            guard settings.addons.indices.contains(index) else { return }
            var uses = settings.addons[index].uses
            if on { uses.insert(use) } else { uses.remove(use) }
            settings.addons[index].chosenUses = uses
        })
    }

    private func usesNote(_ addon: AddonEntry) -> String {
        addon.chosenUses == nil
            ? String(localized: "Automatic: from what the addon says it offers. Untick what you don't want it searched for, e.g. a sports addon for movies.")
            : String(localized: "Chosen by you. Movies and series are only looked for in the addons ticked for them, and so are matches in Sports.")
    }
}

/// Settings › Connections › Add addon: paste a manifest address, checked before it's added.
struct AddAddonView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var status: String?
    @State private var adding = false

    var body: some View {
        SettingsPage("Add addon") {
            SettingsGroup("Manifest address") {
                SettingsFieldRow(title: "Address", icon: "link", prompt: "https://…/manifest.json", keyboard: .URL,
                                 text: $address)
                    .onSubmit { Task { await add() } }
            }
            SettingsNote("Use the manifest link from the addon's own configuration page. Only results with a direct link can be played; torrent-only results are hidden.")

            Button {
                Task { await add() }
            } label: {
                Text(adding ? "Checking…" : "Add addon")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.glassProminent)
            .disabled(adding || address.trimmingCharacters(in: .whitespaces).isEmpty)

            if let status {
                SettingsNote(status)
            }
        }
    }

    private func add() async {
        guard let url = StremioAddonClient.normalize(address) else {
            status = "That isn't a valid address."
            return
        }
        guard !settings.addons.contains(where: { $0.manifestURL == url.absoluteString }) else {
            status = "That addon is already added."
            return
        }
        adding = true
        defer { adding = false }
        do {
            let manifest = try await StremioAddonClient(manifestURL: url).manifest()
            settings.addons.append(AddonEntry(manifestURL: url.absoluteString, name: manifest.name,
                                              detectedUses: AddonUse.offered(by: manifest)))
            dismiss()
        } catch {
            status = "Couldn't load it. Check the address."
        }
    }
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
