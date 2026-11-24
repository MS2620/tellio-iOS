import SwiftUI

/// Settings › Connections › an addon: what it provides, its place in the order, rename, remove.
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
            settings.addons.append(AddonEntry(manifestURL: url.absoluteString, name: manifest.name))
            dismiss()
        } catch {
            status = "Couldn't load it. Check the address."
        }
    }
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
