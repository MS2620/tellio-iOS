import SwiftUI

enum AppTab: Hashable {
    case home, browse, live, sports, search
}

/// The Liquid Glass tab bar: Home, Browse, Live TV and Sports in the bar, Search as its own
/// glass button. On iPad the same bar sits at the top and can open into a sidebar.
/// Settings is behind the gear on Home, not a tab.
struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var tab: AppTab = .home
    @State private var showingSettings = false

    var body: some View {
        TabView(selection: $tab) {
            Tab("Home", systemImage: "house", value: .home) {
                HomeView(showSettings: { showingSettings = true })
            }
            Tab("Browse", systemImage: "film.stack", value: .browse) {
                BrowseView()
            }
            Tab("Live TV", systemImage: "tv", value: .live) {
                LiveTVView()
            }
            Tab("Sports", systemImage: "soccerball", value: .sports) {
                SportsView()
            }
            Tab(value: .search, role: .search) {
                SearchView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        // Reminders slide in over every tab, and become notifications for when Tellio is closed.
        .overlay(alignment: .top) { ReminderBanner() }
        .task { await ReminderStore.shared.run() }
        .onAppear { PlayerSession.shared.settings = settings }
        .onReceive(ReminderStore.shared.$allReminders) { _ in ReminderNotifications.sync() }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}
