#if canImport(UIKit) && os(iOS)
import CoreMotion
import Faro
import SwiftUI
import UIKit

extension View {
    /**
     Presents ``FaroHelpView`` in a sheet while `isPresented` is `true`, taking
     the screenshot of what was on screen first.

     ```swift
     Button("Help") { showHelp = true }
         .faroHelpSheet(isPresented: $showHelp)
     ```

     - Parameters:
       - isPresented: Set it to `true` to open the screen; it goes back to `false` when it closes.
       - faro: The client to use. ``Faro/shared`` by default.
       - locale: The language for the form and the screen.
       - captureScreenshot: Whether to offer a capture of the current screen as an attachment.
       - prefill: Values to start with.
       - device: Extra device facts of your own.
       - onSent: Called once the request is in.
     */
    public func faroHelpSheet(
        isPresented: Binding<Bool>,
        faro: Faro = .shared,
        locale: String? = nil,
        captureScreenshot: Bool = true,
        prefill: FaroPrefill = FaroPrefill(),
        device: [String: String] = [:],
        onSent: ((FaroTicket) -> Void)? = nil
    ) -> some View {
        modifier(FaroHelpSheet(
            isPresented: isPresented, faro: faro, locale: locale, captureScreenshot: captureScreenshot,
            prefill: prefill, device: device, onSent: onSent
        ))
    }

    /**
     Opens ``FaroHelpView`` (with a screenshot) when the person shakes the
     device, while this view is on screen.

     It listens to the accelerometer, which needs no permission, only while the
     view is visible. The simulator has no accelerometer: there, add a button too.
     */
    public func faroShakeToReport(
        isEnabled: Bool = true,
        faro: Faro = .shared,
        locale: String? = nil,
        prefill: FaroPrefill = FaroPrefill(kind: .problem),
        device: [String: String] = [:],
        onSent: ((FaroTicket) -> Void)? = nil
    ) -> some View {
        modifier(ShakeToReport(
            isEnabled: isEnabled, faro: faro, locale: locale, prefill: prefill, device: device, onSent: onSent
        ))
    }
}

/**
 Keeps its own presentation flag so the screenshot is taken while the app's
 screen is still the one showing, before the sheet starts sliding in.
 */
private struct FaroHelpSheet: ViewModifier {
    @Binding var isPresented: Bool
    let faro: Faro
    let locale: String?
    let captureScreenshot: Bool
    let prefill: FaroPrefill
    let device: [String: String]
    let onSent: ((FaroTicket) -> Void)?

    @State private var presented = false
    @State private var screenshot: UIImage?
    @Environment(\.faroTheme) private var theme

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { show in sync(show) }
            .onAppear { sync(isPresented) }
            .sheet(isPresented: Binding(
                get: { presented },
                set: { value in
                    presented = value
                    if !value {
                        isPresented = false
                        screenshot = nil
                    }
                }
            )) {
                FaroHelpView(
                    faro: faro, locale: locale, screenshot: screenshot, prefill: prefill, device: device,
                    onSent: onSent
                ) {
                    presented = false
                    isPresented = false
                }
                .faroTheme(theme)
            }
    }

    private func sync(_ show: Bool) {
        if show && !presented {
            screenshot = captureScreenshot ? FaroScreenshot.captureKeyWindow() : nil
            presented = true
        } else if !show && presented {
            presented = false
        }
    }
}

private struct ShakeToReport: ViewModifier {
    let isEnabled: Bool
    let faro: Faro
    let locale: String?
    let prefill: FaroPrefill
    let device: [String: String]
    let onSent: ((FaroTicket) -> Void)?

    @StateObject private var detector = ShakeDetector()
    @State private var showing = false

    func body(content: Content) -> some View {
        content
            .faroHelpSheet(
                isPresented: $showing, faro: faro, locale: locale, prefill: prefill, device: device, onSent: onSent
            )
            .onAppear { if isEnabled { detector.start() } }
            .onDisappear { detector.stop() }
            .onChange(of: isEnabled) { enabled in enabled ? detector.start() : detector.stop() }
            .onReceive(detector.$shakes.dropFirst()) { _ in
                if !showing { showing = true }
            }
    }
}

/**
 Tells a shake from the accelerometer: two strong jolts (over 2.3 g) within
 0.6 s. Checks 20 times a second, only while started.
 */
@MainActor
final class ShakeDetector: ObservableObject {
    @Published private(set) var shakes = 0

    private let motion = CMMotionManager()
    private var lastJolt: TimeInterval = 0
    private var lastShake: TimeInterval = 0

    func start() {
        guard motion.isAccelerometerAvailable, !motion.isAccelerometerActive else { return }
        motion.accelerometerUpdateInterval = 1.0 / 20
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            let a = data.acceleration
            let force = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
            let time = data.timestamp
            MainActor.assumeIsolated { self?.observe(force: force, at: time) }
        }
    }

    func stop() {
        if motion.isAccelerometerActive { motion.stopAccelerometerUpdates() }
    }

    private func observe(force: Double, at time: TimeInterval) {
        guard force > 2.3 else { return }
        if time - lastJolt < 0.6 && time - lastShake > 1.5 {
            lastShake = time
            shakes += 1
        }
        lastJolt = time
    }
}
#endif
