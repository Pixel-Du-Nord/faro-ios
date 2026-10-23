import Faro
import SwiftUI

/// Which Faro to talk to, a test identity, and the theme.
struct SettingsView: View {
    @AppStorage("faro.key") private var key = ExampleSettings.defaultKey
    @AppStorage("faro.app") private var app = ExampleSettings.defaultApp
    @AppStorage("faro.locale") private var locale = ""
    @AppStorage("theme.accent") private var accent = "brand"
    @AppStorage("theme.shape") private var shape = "rounded"
    @AppStorage("theme.typography") private var typography = "system"
    @State private var signedIn = Faro.currentUser != nil

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("wk_…", text: $key)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    TextField("App slug", text: $app)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    Picker("Language", selection: $locale) {
                        Text("Device").tag("")
                        Text("English").tag("en")
                        Text("Español").tag("es")
                        Text("Português").tag("pt-BR")
                    }
                    Button("Apply") {
                        ExampleSettings.configureFaro()
                        Faro.breadcrumb("Changed the Faro settings")
                    }
                } header: {
                    Text("Faro")
                } footer: {
                    Text("Production API, Pixel du Nord's public widget key and the \"parques\" app by default.")
                }

                Section {
                    Toggle("Signed in as a test player", isOn: $signedIn)
                        .onChange(of: signedIn) { on in
                            Faro.identify(on ? FaroUser(
                                id: "example-player-1",
                                email: "faro-prueba+sdk-ios@pixeldunord.com",
                                name: "Faro iOS SDK"
                            ) : nil)
                        }
                } header: {
                    Text("Identity")
                } footer: {
                    Text("Unsigned: it only prefills the email and name. A signature from your server links the contact.")
                }

                Section("Theme") {
                    Picker("Accent", selection: $accent) {
                        Text("Organization").tag("brand")
                        Text("Indigo").tag("indigo")
                        Text("Green").tag("green")
                        Text("Pink").tag("pink")
                    }
                    Picker("Shape", selection: $shape) {
                        Text("Rounded").tag("rounded")
                        Text("Square").tag("square")
                        Text("Pill").tag("pill")
                    }
                    Picker("Typography", selection: $typography) {
                        Text("System").tag("system")
                        Text("Rounded").tag("rounded")
                        Text("Serif").tag("serif")
                        Text("Monospaced").tag("monospaced")
                    }
                }

                Section("Breadcrumbs") {
                    ForEach(Array(Faro.breadcrumbs.enumerated()), id: \.offset) { _, crumb in
                        Text(crumb.message).font(.footnote)
                    }
                    Button("Clear", role: .destructive) { Faro.clearBreadcrumbs() }
                }

                Section("Device facts") {
                    ForEach(FaroDevice.facts().sorted { $0.key < $1.key }, id: \.key) { fact in
                        HStack {
                            Text(fact.key).foregroundStyle(.secondary)
                            Spacer()
                            Text(fact.value)
                        }
                        .font(.system(.footnote, design: .monospaced))
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .navigationViewStyle(.stack)
    }
}
