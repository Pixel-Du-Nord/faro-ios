#if canImport(UIKit) && !os(watchOS)
import UIKit

/**
 Captures what the app is showing, to attach it to a request.

 Take it **before** presenting your help screen, so it shows what the person
 was looking at, and let them review it (FaroUI's editor lets them cover
 private data) before it is attached. Nothing is captured or sent on its own.

 ```swift
 let shot = FaroScreenshot.captureKeyWindow()
 showHelp = true   // FaroHelpView(screenshot: shot) { … }
 ```
 */
@MainActor
public enum FaroScreenshot {
    /// The app's key window as an image, or `nil` if there is no visible window.
    public static func captureKeyWindow() -> UIImage? {
        guard let window = keyWindow else { return nil }
        return capture(window)
    }

    /// Any view (and what it contains) as an image, or `nil` if it has no size.
    public static func capture(_ view: UIView) -> UIImage? {
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat(for: view.traitCollection)
        // Retina is plenty to read a screenshot; 3x only costs memory.
        format.scale = min(view.window?.screen.scale ?? 2, 2)
        format.opaque = true
        return UIGraphicsImageRenderer(bounds: bounds, format: format).image { _ in
            view.drawHierarchy(in: bounds, afterScreenUpdates: false)
        }
    }

    /// The key window of the foreground scene.
    static var keyWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let ordered = scenes.filter { $0.activationState == .foregroundActive }
            + scenes.filter { $0.activationState != .foregroundActive }
        for scene in ordered {
            if let key = scene.windows.first(where: \.isKeyWindow) { return key }
        }
        return ordered.lazy.flatMap(\.windows).first { !$0.isHidden && $0.bounds.width > 0 }
    }
}
#endif
