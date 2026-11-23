import SwiftUI

/// League tables for your teams' leagues, one tab per league, plus F1 championships.
/// Your teams' rows are highlighted.
struct LeagueTablesSection: View {
    let teams: [FavouriteTeam]
    @State private var tabs: [StandingTab] = []
    @State private var selectedID: String?
    @State private var loading = true

    private var selected: StandingTab? { tabs.first { $0.id == selectedID } ?? tabs.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RailTitle(text: "Tables")

            if tabs.isEmpty {
                Text(loading ? "Loading tables…" : "No tables for your teams' leagues.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tabs) { tab in
                            let isSelected = tab.id == selected?.id
                            Button(tab.title) { selectedID = tab.id }
                                .font(.subheadline.weight(.bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .foregroundStyle(isSelected ? Theme.ink : .white)
                                .background(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.12)),
                                            in: .capsule)
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                if let selected {
                    VStack(spacing: 16) {
                        ForEach(selected.tables) { table in
                            StandingTableView(table: table, showsTitle: selected.tables.count > 1)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .task(id: teams.map(\.id)) {
            loading = true
            tabs = await StandingsClient().tabs(for: teams)
            loading = false
        }
    }
}

private struct StandingTableView: View {
    let table: StandingTable
    let showsTitle: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if showsTitle {
                Text(table.title.uppercased())
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
            }
            header
            ForEach(table.rows) { row in
                StandingRowView(row: row, football: table.showsPlayedAndDifference)
            }
        }
        .padding(10)
        .glassPanel(cornerRadius: 20)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("#").frame(width: 30, alignment: .leading)
            Text(table.showsPlayedAndDifference ? "TEAM" : "NAME").frame(maxWidth: .infinity, alignment: .leading)
            if table.showsPlayedAndDifference {
                Text("P").frame(width: 34, alignment: .trailing)
                Text("GD").frame(width: 42, alignment: .trailing)
            } else {
                Text("WINS").frame(width: 50, alignment: .trailing)
            }
            Text("PTS").frame(width: 44, alignment: .trailing)
        }
        .font(.caption2.weight(.heavy))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }
}

private struct StandingRowView: View {
    let row: StandingRow
    let football: Bool

    var body: some View {
        HStack(spacing: 0) {
            Text("\(row.rank)").frame(width: 30, alignment: .leading)
            HStack(spacing: 8) {
                if let logo = row.logo, let url = URL(string: logo) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Color.clear
                    }
                    .frame(width: 22, height: 22)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.name).lineLimit(1)
                    if let detail = row.detail {
                        Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if football {
                Text(row.played ?? "—").foregroundStyle(.secondary).frame(width: 34, alignment: .trailing)
                Text(row.difference ?? "—").foregroundStyle(.secondary).frame(width: 42, alignment: .trailing)
            } else {
                Text((row.played ?? "—").replacingOccurrences(of: " wins", with: ""))
                    .foregroundStyle(.secondary).frame(width: 50, alignment: .trailing)
            }
            Text(row.points).frame(width: 44, alignment: .trailing)
        }
        .font(.subheadline.weight(row.isFollowed ? .heavy : .medium))
        .monospacedDigit()
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(row.isFollowed ? Color.white.opacity(0.18) : .clear, in: .rect(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}
