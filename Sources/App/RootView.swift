import SwiftUI

enum AppTab: Hashable {
    case home, browse, live, sports, search
}

/// The Liquid Glass tab bar: Home, Browse, Live TV and Sports in the bar, Search as its own
/// glass button. On iPad the same bar sits at the top and can open into a sidebar.
/// Settings is behind the gear on Home, not a tab.
struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var router = AppRouter.shared
    @ObservedObject private var reminders = ReminderStore.shared
    @State private var showingSettings = false

    var body: some View {
        TabView(selection: $router.tab) {
            Tab(String(localized: "tab.home", defaultValue: "Home", comment: "Tab bar: keep it short, or the tabs crowd the bar"), systemImage: "house", value: .home) {
                HomeView(showSettings: { showingSettings = true })
            }
            Tab(String(localized: "tab.browse", defaultValue: "Browse", comment: "Tab bar: keep it short, or the tabs crowd the bar"), systemImage: "film.stack", value: .browse) {
                BrowseView()
            }
            Tab(String(localized: "tab.liveTV", defaultValue: "Live TV", comment: "Tab bar: keep it short, or the tabs crowd the bar"), systemImage: "tv", value: .live) {
                LiveTVView()
            }
            Tab(String(localized: "tab.sports", defaultValue: "Sports", comment: "Tab bar: keep it short, or the tabs crowd the bar"), systemImage: "soccerball", value: .sports) {
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
        // What each addon offers, for addons added before categories (and ones that changed).
        .task { await settings.detectAddonUses() }
        .onAppear { PlayerSession.shared.settings = settings }
        .onReceive(reminders.$allReminders) { _ in ReminderNotifications.sync() }
        .onReceive(reminders.$matches) { _ in ReminderNotifications.sync() }
        .onChange(of: settings.prefs.reminderLeadMinutes) { ReminderNotifications.sync() }
        .onChange(of: settings.xtream.id) { ReminderNotifications.sync() }
        // A reminder taking you to Live TV or a match closes Settings if it's open.
        .onChange(of: router.routed) { showingSettings = false }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}
