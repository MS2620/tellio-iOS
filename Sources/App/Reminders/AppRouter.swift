import SwiftUI

/// The selected tab and the Sports tab's navigation, so a reminder (its notification or its
/// banner) can take you to Live TV, or to a match's page to pick where to watch it.
@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var tab: AppTab = .home
    @Published var sportsPath = NavigationPath()
    /// Bumped when a reminder takes you somewhere, so sheets over the tabs close.
    @Published private(set) var routed = 0

    private init() {}

    /// The Sports tab, showing the match's page.
    func openMatch(_ fixture: Fixture) {
        tab = .sports
        var path = NavigationPath()
        path.append(fixture)
        sportsPath = path
        routed += 1
    }

    func openLiveTV() {
        tab = .live
        routed += 1
    }
}
