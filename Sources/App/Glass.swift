import SwiftUI

/// Liquid Glass building blocks for the iOS screens, over Tellio's background.

extension View {
    /// A glass panel, for grouped rows, score cards and the like.
    func glassPanel(cornerRadius: CGFloat = 20) -> some View {
        glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }

    /// Tellio's background (Frosted by default, or the one picked in Settings) behind a screen.
    func appBackground() -> some View {
        background { AppBackground() }
    }
}

/// A small uppercase section header above a glass panel, as in iOS grouped lists.
struct SectionHeader: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(.footnote.weight(.semibold))
            .tracking(0.5)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A round glass icon button, like the Settings gear on Home.
struct GlassIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    init(_ systemImage: String, label: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(label)
    }
}
