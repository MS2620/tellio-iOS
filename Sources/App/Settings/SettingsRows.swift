import SwiftUI

/// Building blocks for the grouped glass lists in Settings.

/// A settings screen: Tellio's background, a scrolling column of groups and a large title.
struct SettingsPage<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .appBackground()
        .navigationTitle(title)
    }
}

/// A titled glass panel of rows with hairlines between them, like an iOS grouped list.
struct SettingsGroup<Content: View>: View {
    let title: String?
    let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 6) {
            if let title { SectionHeader(title) }
            VStack(spacing: 0) {
                Group(subviews: content) { rows in
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 {
                            Divider().overlay(.white.opacity(0.08)).padding(.leading, 58)
                        }
                        row
                    }
                }
            }
            .glassPanel(cornerRadius: 18)
        }
    }
}

/// Icon tile, title, optional subtitle and a trailing value. Used by every row type.
struct SettingsRowLabel: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    var value: String? = nil
    var showsChevron = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.16), in: .rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                if let subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let value {
                Text(value).foregroundStyle(.secondary).lineLimit(1)
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

/// A row that opens another settings screen.
struct SettingsLink<Destination: View>: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    var value: String? = nil
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            SettingsRowLabel(title: title, subtitle: subtitle, icon: icon, value: value, showsChevron: true)
        }
        .buttonStyle(.plain)
    }
}

/// A row that only shows a value.
struct SettingsInfoRow: View {
    let title: String
    let icon: String
    let value: String

    var body: some View {
        SettingsRowLabel(title: title, icon: icon, value: value)
    }
}

/// A row with a switch.
struct SettingsToggleRow: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 0) {
            SettingsRowLabel(title: title, subtitle: subtitle, icon: icon)
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .padding(.trailing, 14)
        }
    }
}

/// A row with a text field, e.g. a server address or password.
struct SettingsFieldRow: View {
    let title: String
    let icon: String
    var prompt = ""
    var secure = false
    var keyboard: UIKeyboardType = .default
    @Binding var text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.16), in: .rect(cornerRadius: 8))
            Group {
                if secure {
                    SecureField(title, text: $text, prompt: Text(prompt.isEmpty ? title : prompt))
                } else {
                    TextField(title, text: $text, prompt: Text(prompt.isEmpty ? title : prompt))
                        .keyboardType(keyboard)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 52)
    }
}

/// A small note under a group.
struct SettingsNote: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A settings screen that isn't built yet.
struct ComingSoonPage: View {
    let title: String

    var body: some View {
        SettingsPage(title) {
            SettingsNote("Coming soon on iPhone and iPad. Until then, set this up on the Apple TV and bring it across with a backup code.")
        }
    }
}
