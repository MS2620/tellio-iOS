import SwiftUI

/// Settings › Appearance: the background behind every screen. Changes show straight away.
struct AppearanceView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        SettingsPage("Appearance") {
            SettingsGroup("Background") {
                ForEach(BackgroundStyle.allCases) { style in
                    Button {
                        settings.prefs.backgroundStyle = style
                    } label: {
                        HStack(spacing: 0) {
                            SettingsRowLabel(title: style.label, icon: "circle.lefthalf.filled")
                            if settings.prefs.backgroundStyle == style {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.bold))
                                    .padding(.trailing, 16)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(settings.prefs.backgroundStyle == style ? .isSelected : [])
                }
            }
        }
    }
}
