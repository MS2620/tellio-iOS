import SwiftUI

// Copied from the Apple TV app (Vendor/tellio/Sources/Views/Theme.swift) because that file also
// holds tvOS-only focus code. Keep the colours in step with it.

enum Theme {
    /// The page background that hero artwork fades into.
    static let base = Color(red: 0.055, green: 0.065, blue: 0.09)
    /// Dark text on white cards and tiles.
    static let ink = Color(red: 0.08, green: 0.08, blue: 0.1)
    static let live = Color(red: 1, green: 0.3, blue: 0.3)
    static let good = Color(red: 0.29, green: 0.87, blue: 0.5)
    static let warning = Color(red: 1, green: 0.75, blue: 0.3)
}

/// The soft, frosted backdrop behind Live TV, Sports, Calendar, Search and Settings.
struct AppBackground: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ZStack {
            switch settings.prefs.backgroundStyle {
            case .frosted:
                Color(red: 0.2, green: 0.24, blue: 0.31)
                RadialGradient(colors: [Color(red: 0.62, green: 0.5, blue: 0.45).opacity(0.55), .clear],
                               center: UnitPoint(x: 0.72, y: 0.3), startRadius: 0, endRadius: 900)
                RadialGradient(colors: [Color(red: 0.35, green: 0.5, blue: 0.7).opacity(0.6), .clear],
                               center: UnitPoint(x: 0.1, y: 0.15), startRadius: 0, endRadius: 800)
                RadialGradient(colors: [Color(red: 0.55, green: 0.4, blue: 0.55).opacity(0.4), .clear],
                               center: UnitPoint(x: 0.45, y: 0.95), startRadius: 0, endRadius: 800)
                LinearGradient(colors: [.clear, Theme.base.opacity(0.5)], startPoint: .top, endPoint: .bottom)
            case .dark:
                Theme.base
            case .black:
                Color.black
            case .ocean:
                Glows(base: (18, 40, 58), glows: [((40, 170, 180), 0.45, 0.75, 0.25), ((40, 90, 200), 0.55, 0.1, 0.2),
                                                  ((60, 140, 160), 0.35, 0.5, 0.95)])
            case .sunset:
                Glows(base: (46, 31, 42), glows: [((230, 120, 70), 0.45, 0.75, 0.25), ((200, 70, 120), 0.45, 0.1, 0.2),
                                                  ((110, 60, 140), 0.4, 0.5, 0.95)])
            case .forest:
                Glows(base: (24, 38, 31), glows: [((90, 140, 80), 0.45, 0.75, 0.25), ((40, 110, 100), 0.5, 0.1, 0.2),
                                                  ((120, 120, 60), 0.3, 0.5, 0.95)])
            case .aurora:
                Glows(base: (16, 24, 40), glows: [((60, 200, 150), 0.35, 0.7, 0.2), ((130, 80, 200), 0.45, 0.15, 0.3),
                                                  ((40, 90, 180), 0.4, 0.5, 0.95)])
            case .rose:
                Glows(base: (43, 32, 38), glows: [((220, 150, 160), 0.4, 0.72, 0.28), ((170, 120, 170), 0.4, 0.12, 0.18),
                                                  ((230, 180, 150), 0.3, 0.48, 0.95)])
            }
        }
        .ignoresSafeArea()
    }
}

/// A soft background like Frosted: coloured glows over a dark base, darker towards the bottom.
private struct Glows: View {
    typealias RGB = (Double, Double, Double)
    let base: RGB
    /// Colour, strength and centre (x, y from 0 to 1).
    let glows: [(RGB, Double, Double, Double)]

    private static func color(_ rgb: RGB) -> Color {
        Color(red: rgb.0 / 255, green: rgb.1 / 255, blue: rgb.2 / 255)
    }

    var body: some View {
        ZStack {
            Self.color(base)
            ForEach(glows.indices, id: \.self) { index in
                let glow = glows[index]
                RadialGradient(colors: [Self.color(glow.0).opacity(glow.1), .clear],
                               center: UnitPoint(x: glow.2, y: glow.3), startRadius: 0, endRadius: 850)
            }
            LinearGradient(colors: [.clear, Theme.base.opacity(0.5)], startPoint: .top, endPoint: .bottom)
        }
    }
}
