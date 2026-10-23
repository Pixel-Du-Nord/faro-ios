#if canImport(UIKit) && os(iOS)
import SwiftUI
import UIKit

/**
 How FaroUI looks: the accent color, the shape of fields and buttons, and the
 typeface. Apply it with ``SwiftUI/View/faroTheme(_:)``.

 ```swift
 FaroHelpView { showHelp = false }
     .faroTheme(FaroTheme(accent: .indigo, shape: .pill, typography: .rounded))
 ```

 Colors adapt to light and dark mode on their own; only the accent is yours.
 */
public struct FaroTheme: Sendable, Hashable {
    /// The corners of fields, cards and buttons.
    public enum Shape: Sendable, Hashable {
        /// Soft, continuous corners (the default).
        case rounded
        /// Nearly square corners.
        case square
        /// Fully rounded buttons and chips, soft cards.
        case pill
    }

    /// The typeface. Every option follows Dynamic Type.
    public enum Typography: Sendable, Hashable {
        /// San Francisco.
        case system
        /// SF Rounded.
        case rounded
        /// New York.
        case serif
        /// SF Mono.
        case monospaced
        /// A font bundled with your app, by its PostScript name. Bold text asks the system for a heavier weight.
        case custom(String)
    }

    /**
     The accent: selected options, the send button, links. `nil` uses the
     organization's brand color from the Faro panel, then your app's tint.
     */
    public var accent: Color?
    public var shape: Shape
    public var typography: Typography

    public init(accent: Color? = nil, shape: Shape = .rounded, typography: Typography = .system) {
        self.accent = accent
        self.shape = shape
        self.typography = typography
    }

    /// The organization's color, soft corners and the system font.
    public static let `default` = FaroTheme()
}

extension View {
    /// Styles every FaroUI view inside this one.
    public func faroTheme(_ theme: FaroTheme) -> some View {
        environment(\.faroTheme, theme)
    }

    /// Styles every FaroUI view inside this one.
    public func faroTheme(
        accent: Color? = nil,
        shape: FaroTheme.Shape = .rounded,
        typography: FaroTheme.Typography = .system
    ) -> some View {
        environment(\.faroTheme, FaroTheme(accent: accent, shape: shape, typography: typography))
    }
}

private struct FaroThemeKey: EnvironmentKey {
    static let defaultValue = FaroTheme.default
}

extension EnvironmentValues {
    var faroTheme: FaroTheme {
        get { self[FaroThemeKey.self] }
        set { self[FaroThemeKey.self] = newValue }
    }
}

/// The theme resolved against the organization's color: what the views draw with.
struct FaroStyle: Sendable {
    let accent: Color
    /// Text and icons on top of the accent: black or white, whichever reads better.
    let onAccent: Color
    /// The accent for text and icons on the page: a light accent (amber, yellow…)
    /// gets darker in light mode so it stays readable on white.
    let accentInk: Color
    let theme: FaroTheme

    init(theme: FaroTheme, brandColor: String?) {
        self.theme = theme
        let accent = theme.accent ?? brandColor.flatMap(Color.init(faroHex:)) ?? Color.accentColor
        self.accent = accent
        let light = Self.luminance(of: accent) > 0.3
        self.onAccent = light ? Color.black.opacity(0.85) : .white
        if light {
            let base = UIColor(accent)
            var h: CGFloat = 0, sat: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            base.getHue(&h, saturation: &sat, brightness: &b, alpha: &a)
            let dark = UIColor(hue: h, saturation: min(1, sat * 1.1), brightness: b * 0.6, alpha: a)
            self.accentInk = Color(UIColor { $0.userInterfaceStyle == .dark ? base : dark })
        } else {
            self.accentInk = accent
        }
    }

    var cardRadius: CGFloat {
        switch theme.shape {
        case .rounded: return 18
        case .square: return 4
        case .pill: return 22
        }
    }

    var fieldRadius: CGFloat {
        switch theme.shape {
        case .rounded: return 12
        case .square: return 3
        case .pill: return 16
        }
    }

    /// The shape of buttons and chips.
    func control(height: CGFloat = 0) -> FaroAnyShape {
        switch theme.shape {
        case .pill: return FaroAnyShape(Capsule(style: .continuous))
        case .square: return FaroAnyShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        case .rounded: return FaroAnyShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    func font(_ style: Font.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        switch theme.typography {
        case .system: return .system(style).weight(weight)
        case .rounded: return .system(style, design: .rounded).weight(weight)
        case .serif: return .system(style, design: .serif).weight(weight)
        case .monospaced: return .system(style, design: .monospaced).weight(weight)
        case .custom(let name): return .custom(name, size: Self.size(of: style), relativeTo: style).weight(weight)
        }
    }

    private static func size(of style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline, .body: return 17
        case .callout: return 16
        case .subheadline: return 15
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        @unknown default: return 17
        }
    }

    private static func luminance(of color: Color) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return 0.5 }
        func linear(_ c: CGFloat) -> CGFloat { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }
}

/// A type-erased shape (SwiftUI's own `AnyShape` needs iOS 16).
struct FaroAnyShape: Shape, @unchecked Sendable {
    private let draw: (CGRect) -> Path

    init<S: Shape>(_ shape: S) { draw = { shape.path(in: $0) } }

    func path(in rect: CGRect) -> Path { draw(rect) }
}

private struct FaroStyleKey: EnvironmentKey {
    static let defaultValue: FaroStyle? = nil
}

extension EnvironmentValues {
    var faroStyle: FaroStyle {
        get { self[FaroStyleKey.self] ?? FaroStyle(theme: faroTheme, brandColor: nil) }
        set { self[FaroStyleKey.self] = newValue }
    }
}

extension Color {
    /// `#rrggbb`.
    init?(faroHex hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}
#endif
