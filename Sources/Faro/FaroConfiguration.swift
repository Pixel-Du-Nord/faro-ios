import Foundation

/// The settings a ``Faro`` client talks to the Faro API with.
public struct FaroConfiguration: Sendable, Hashable {
    /// The production Faro API.
    public static let defaultAPIURL = URL(string: "https://api-faro.pixeldunord.com")!

    /// The public widget key of the organization (`wk_…`).
    public var key: String
    /// The application's slug in Faro, or `nil` to file requests for the whole organization.
    public var app: String?
    /// The language the app shows, or `nil` for the device's preferred language.
    public var locale: String?
    /// The Faro API base URL.
    public var apiURL: URL
    /// How long a single call may take before it fails as a network error, in seconds.
    public var timeout: TimeInterval

    /**
     - Parameters:
       - key: The public widget key (`wk_…`).
       - app: The application's slug in Faro.
       - locale: The app's language (`"es"`, `"pt-BR"`…), or `nil` for the device's.
       - apiURL: The Faro API base URL.
       - timeout: Seconds before a call fails as a network error.
     */
    public init(
        key: String,
        app: String? = nil,
        locale: String? = nil,
        apiURL: URL = FaroConfiguration.defaultAPIURL,
        timeout: TimeInterval = 30
    ) {
        self.key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let slug = app?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.app = (slug?.isEmpty ?? true) ? nil : slug
        self.locale = locale
        self.apiURL = apiURL
        self.timeout = timeout
    }

    var isValid: Bool { !key.isEmpty }
}

/// Language helpers shared by the core and the UI.
public enum FaroLocale {
    /**
     The two-letter language of a locale identifier, lowercased:
     `"pt-BR"` → `"pt"`, `"es_CO"` → `"es"`. `nil` or empty gives the
     device's preferred language.
     */
    public static func language(_ identifier: String?) -> String {
        let raw = (identifier?.isEmpty == false ? identifier : nil)
            ?? Locale.preferredLanguages.first
            ?? "en"
        let base = raw.lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
            .first
            .map(String.init) ?? "en"
        return base.isEmpty ? "en" : base
    }
}

/// The three endpoints of the public API.
struct Endpoints: Sendable {
    let configuration: FaroConfiguration

    private func url(_ path: String, _ query: [URLQueryItem]) -> URL {
        var components = URLComponents(
            url: configuration.apiURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = query
        return components.url!
    }

    /// `GET /widget/config?key=…&app=…`: the form definition.
    var config: URL {
        var query = [URLQueryItem(name: "key", value: configuration.key)]
        if let app = configuration.app { query.append(URLQueryItem(name: "app", value: app)) }
        return url("widget/config", query)
    }

    /// `GET /widget/challenge?key=…`: a proof-of-work puzzle.
    var challenge: URL {
        url("widget/challenge", [URLQueryItem(name: "key", value: configuration.key)])
    }

    /// `POST /widget/requests`: files a request.
    var requests: URL {
        configuration.apiURL.appendingPathComponent("widget/requests")
    }
}
