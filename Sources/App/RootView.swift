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
                ScreenPlaceholder(title: "Sports", detail: "Your teams, live scores and tables")
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

/// A tab that isn't built yet: large title and a short note on a glass panel.
private struct ScreenPlaceholder: View {
    let title: String
    let detail: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(detail)
                    .foregroundStyle(.secondary)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassPanel()
                    .padding(.horizontal, 20)
            }
            .appBackground()
            .navigationTitle(title)
        }
    }
}
