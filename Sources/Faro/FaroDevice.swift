import Foundation
#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

/**
 The device facts that travel with every request, so the team can reproduce a
 problem without asking.

 | Key | Example |
 |---|---|
 | `appVersion` | `2.4.1` (`CFBundleShortVersionString`) |
 | `build` | `318` (`CFBundleVersion`) |
 | `os` | `iOS`, `iPadOS` or `macOS` |
 | `osVersion` | `18.2` |
 | `model` | `iPhone16,2`, or `iPhone17,1 (Simulator)` |
 | `manufacturer` | `Apple` |
 | `locale` | `es_CO` |
 | `timezone` | `America/Bogota` |
 | `screen` | `1179x2556 @3x` (pixels, short side first, and the scale) |
 | `sdk` | `faro-ios 1.0.1` |

 Nothing else is collected: no identifiers, no IP lookups, no location.
 */
public enum FaroDevice {
    /// Faro keeps at most this many device facts per request.
    public static let maxFacts = 12

    /**
     The automatic facts plus your own (`extra`), at most ``maxFacts``: the
     automatic ones take precedence for room, yours win on the same key.
     */
    public static func facts(adding extra: [String: String] = [:]) -> [String: String] {
        compose(extra: extra, trail: nil, userId: nil)
    }

    /**
     The `device` object of a request: the automatic facts, then the breadcrumb
     `trail` and the unsigned `userId`, then the app's `extra` ones (which win on
     the same key), clipped to Faro's limits. Same order as the Android SDK.
     */
    static func compose(extra: [String: String], trail: String?, userId: String?) -> [String: String] {
        var facts = automatic()
        func put(_ key: String, _ value: String?) {
            let name = String(key.trimmingCharacters(in: .whitespaces).prefix(40))
            let clean = (value ?? "").components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }.joined(separator: " ")
            guard !name.isEmpty, name != "app", !clean.isEmpty else { return }
            if facts[name] == nil && facts.count >= maxFacts { return }
            facts[name] = String(clean.prefix(120))
        }
        put("trail", trail)
        put("userId", userId)
        for key in extra.keys.sorted() { put(key, extra[key]) }
        return facts
    }

    /// The facts gathered by the SDK, without any of the app's.
    public static func automatic() -> [String: String] {
        let info = Bundle.main.infoDictionary ?? [:]
        let model = modelIdentifier
        let version = ProcessInfo.processInfo.operatingSystemVersion
        var osVersion = "\(version.majorVersion).\(version.minorVersion)"
        if version.patchVersion > 0 { osVersion += ".\(version.patchVersion)" }
        let facts: [String: String] = [
            "appVersion": info["CFBundleShortVersionString"] as? String ?? "",
            "build": info["CFBundleVersion"] as? String ?? "",
            "os": operatingSystem(model: model),
            "osVersion": osVersion,
            "model": model,
            "manufacturer": "Apple",
            "locale": Locale.current.identifier,
            "timezone": TimeZone.current.identifier,
            "screen": screen ?? "",
            "sdk": "faro-ios \(Faro.version)",
        ]
        return facts.filter { !$0.value.isEmpty }
    }

    // MARK: Screen

    /// Read once on the main thread (UIKit's screen lives there) and kept: it does not change.
    private static let screenFact = Locked<String?>(nil)

    /// The screen in pixels, short side first, and its scale: `1179x2556 @3x`. `nil` off iOS.
    static var screen: String? {
        if let known = screenFact.withLock({ $0 }) { return known }
        #if canImport(UIKit) && !os(watchOS)
        guard Thread.isMainThread else { return nil }
        let value = MainActor.assumeIsolated { () -> String in
            let screen = UIScreen.main
            let size = screen.nativeBounds.size
            let short = Int(min(size.width, size.height)), long = Int(max(size.width, size.height))
            return "\(short)x\(long) @\(Int(screen.scale.rounded()))x"
        }
        screenFact.withLock { $0 = value }
        return value
        #else
        return nil
        #endif
    }

    /// Reads the screen on the main thread ahead of time, so a request sent from anywhere carries it.
    static func primeScreen() {
        #if canImport(UIKit) && !os(watchOS)
        if screenFact.withLock({ $0 }) != nil { return }
        Task { @MainActor in _ = screen }
        #endif
    }

    /**
     The hardware model identifier (`iPhone16,2`), which is what tells devices
     apart (`UIDevice.model` only says "iPhone"). In the simulator it is the
     simulated model followed by ` (Simulator)`.
     */
    public static var modelIdentifier: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"], !simulated.isEmpty {
            return simulated + " (Simulator)"
        }
        if runsOnMac, let mac = sysctl("hw.model") { return mac }
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: &system.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    private static var runsOnMac: Bool {
        #if os(macOS) || targetEnvironment(macCatalyst)
        return true
        #else
        if #available(iOS 14.0, *) { return ProcessInfo.processInfo.isiOSAppOnMac }
        return false
        #endif
    }

    private static func operatingSystem(model: String) -> String {
        #if os(iOS)
        if runsOnMac { return "macOS" }
        return model.hasPrefix("iPad") ? "iPadOS" : "iOS"
        #elseif os(macOS)
        return "macOS"
        #elseif os(tvOS)
        return "tvOS"
        #elseif os(watchOS)
        return "watchOS"
        #else
        return "visionOS"
        #endif
    }

    private static func sysctl(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        let value = String(cString: buffer)
        return value.isEmpty ? nil : value
    }
}
