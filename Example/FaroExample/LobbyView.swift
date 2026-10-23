import Faro
import FaroUI
import SwiftUI

/// A made-up game lobby. The point: it has a player card with "private" data
/// that shows up in the screenshot, to try covering it in the editor.
struct LobbyView: View {
    @State private var showHelp = false
    @State private var lastTicket: FaroTicket?

    private let tables: [(name: String, color: Color, players: Int, stake: Int)] = [
        ("Mesa Roja", .red, 3, 50),
        ("Mesa Amarilla", .yellow, 2, 100),
        ("Mesa Verde", .green, 4, 25),
        ("Mesa Azul", .blue, 1, 200),
    ]

    var body: some View {
        NavigationView {
            List {
                Section {
                    playerCard
                }
                Section("Tables") {
                    ForEach(tables, id: \.name) { table in
                        Button {
                            Faro.breadcrumb("Opened \(table.name)")
                        } label: {
                            HStack(spacing: 14) {
                                Circle().fill(table.color).frame(width: 34, height: 34)
                                    .overlay(Image(systemName: "die.face.\(table.players + 1).fill").foregroundStyle(.white))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(table.name).font(.headline)
                                    Text("\(table.players)/4 players · \(table.stake) coins")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                        }
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("example.table.\(table.name)")
                    }
                }
                if let lastTicket {
                    Section("Last request") {
                        Label("#\(lastTicket.number) · replies to \(lastTicket.email)", systemImage: "checkmark.seal.fill")
                            .accessibilityIdentifier("example.lastTicket")
                    }
                }
                Section {
                    Text("Shake the device (or tap the lifebuoy) to report a problem with a screenshot of this screen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Parqués Lobby")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Faro.breadcrumb("Tapped Help in the lobby")
                        showHelp = true
                    } label: {
                        Image(systemName: "lifepreserver")
                    }
                    .accessibilityLabel("Help")
                    .accessibilityIdentifier("example.help")
                }
            }
        }
        .navigationViewStyle(.stack)
        .faroHelpSheet(
            isPresented: $showHelp,
            locale: ExampleSettings.locale,
            prefill: Self.launchPrefill,
            device: ["build.flavor": "example"]
        ) { ticket in
            lastTicket = ticket
        }
        .faroShakeToReport(locale: ExampleSettings.locale)
        .onAppear {
            if UserDefaults.standard.bool(forKey: "example.openHelp") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showHelp = true }
            }
        }
    }

    private static var launchPrefill: FaroPrefill {
        guard UserDefaults.standard.bool(forKey: "example.prefill") else { return FaroPrefill() }
        return FaroPrefill(
            kind: .problem,
            message: "The dice froze after my second roll at Mesa Roja.",
            fields: ["where": "online"]
        )
    }

    private var playerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.orange)
                Text("AM").font(.headline).foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text("Ana Martínez").font(.headline)
                Text("ana.martinez@example.com").font(.subheadline).foregroundStyle(.secondary)
                Text("Card •••• 4242 · 1,250 coins").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
