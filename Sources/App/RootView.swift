import SwiftUI

enum AppTab: Hashable {
    case home, browse, live, sports, search
}

/// The Liquid Glass tab bar: Home, Browse, Live TV and Sports in the bar, Search as its own
/// glass button. On iPad the same bar sits at the top and can open into a sidebar.
/// Settings is behind the gear on Home, not a tab.
struct RootView: View {
    @State private var tab: AppTab = .home
    @State private var showingSettings = false
    @State private var searchText = ""

    var body: some View {
        TabView(selection: $tab) {
            Tab("Home", systemImage: "house", value: .home) {
                HomePlaceholder(showSettings: { showingSettings = true })
            }
            Tab("Browse", systemImage: "film.stack", value: .browse) {
                ScreenPlaceholder(title: "Browse", detail: "Movies, Series and Calendar")
            }
            Tab("Live TV", systemImage: "tv", value: .live) {
                LiveTVView()
            }
            Tab("Sports", systemImage: "soccerball", value: .sports) {
                ScreenPlaceholder(title: "Sports", detail: "Your teams, live scores and tables")
            }
            Tab(value: .search, role: .search) {
                NavigationStack {
                    ScreenPlaceholder(title: "Search", detail: "Films, series and channels")
                }
                .searchable(text: $searchText, prompt: "Films, series, channels")
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

/// Home's header: the Tellio name and the Settings gear. The rows come later in stage 3.
private struct HomePlaceholder: View {
    let showSettings: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Tellio")
                            .font(.title.weight(.black))
                        Spacer()
                        GlassIconButton("gearshape", label: "Settings", action: showSettings)
                    }
                    .padding(.horizontal, 20)

                    Text("Continue Watching, My List and trending rows will appear here.")
                        .foregroundStyle(.secondary)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassPanel()
                        .padding(.horizontal, 20)
                }
                .padding(.top, 8)
            }
            .appBackground()
            .toolbarVisibility(.hidden, for: .navigationBar)
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
