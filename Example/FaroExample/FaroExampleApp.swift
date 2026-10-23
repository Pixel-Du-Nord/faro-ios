import Faro
import FaroUI
import SwiftUI

/*
 * The Faro SDK example: a made-up game lobby (in the spirit of Parqués) that
 * files real requests to Pixel du Nord's Faro.
 *
 *  - Lobby: the ready-made screen (`.faroHelpSheet`) with the screenshot of
 *    the lobby, which has "private" data to cover, plus shake to report.
 *  - Own UI: the core alone (`form`, `prepare`, `send`) under a minimal screen.
 *  - Settings: key, app, language, a test identity and the theme.
 *
 * Launch arguments (also handy for screenshots):
 *   -faro.key wk_…   -faro.app parques   -faro.locale es
 *   -example.openHelp YES      opens the help sheet on launch
 *   -example.prefill YES       starts it with a kind and a message
 */
@main
struct FaroExampleApp: App {
    init() {
        ExampleSettings.registerDefaults()
        ExampleSettings.configureFaro()
        Faro.breadcrumb("Launched the example app")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Settings kept in `UserDefaults` (and overridable with launch arguments).
enum ExampleSettings {
    static let defaultKey = "wk_c4x3i0bpyxg3v3418e0h"
    static let defaultApp = "parques"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            "faro.key": defaultKey,
            "faro.app": defaultApp,
            "faro.locale": "",
            "theme.accent": "brand",
            "theme.shape": "rounded",
            "theme.typography": "system",
        ])
    }

    static func configureFaro() {
        let defaults = UserDefaults.standard
        let locale = defaults.string(forKey: "faro.locale") ?? ""
        Faro.configure(
            key: defaults.string(forKey: "faro.key") ?? defaultKey,
            app: defaults.string(forKey: "faro.app"),
            locale: locale.isEmpty ? nil : locale
        )
    }

    static var locale: String? {
        let value = UserDefaults.standard.string(forKey: "faro.locale") ?? ""
        return value.isEmpty ? nil : value
    }
}

struct RootView: View {
    @AppStorage("theme.accent") private var accent = "brand"
    @AppStorage("theme.shape") private var shape = "rounded"
    @AppStorage("theme.typography") private var typography = "system"

    var body: some View {
        TabView {
            LobbyView()
                .tabItem { Label("Lobby", systemImage: "die.face.5") }
            OwnUIView()
                .tabItem { Label("Own UI", systemImage: "hammer") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .faroTheme(theme)
    }

    private var theme: FaroTheme {
        let color: Color? = switch accent {
        case "indigo": .indigo
        case "green": .green
        case "pink": .pink
        default: nil
        }
        let shape: FaroTheme.Shape = switch self.shape {
        case "square": .square
        case "pill": .pill
        default: .rounded
        }
        let typography: FaroTheme.Typography = switch self.typography {
        case "rounded": .rounded
        case "serif": .serif
        case "monospaced": .monospaced
        default: .system
        }
        return FaroTheme(accent: color, shape: shape, typography: typography)
    }
}
