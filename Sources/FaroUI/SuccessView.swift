#if canImport(UIKit) && os(iOS)
import Faro
import SwiftUI

/// The request is in: a lighthouse sweeps its beam over the request number.
struct SuccessView: View {
    @ObservedObject var model: HelpModel
    let ticket: FaroTicket
    let onClose: (() -> Void)?

    @Environment(\.faroStyle) private var style

    private var s: FaroStrings { model.strings }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let onClose {
                    HStack {
                        Spacer()
                        CloseButton(label: s.close, action: onClose)
                    }
                }
                LighthouseBeam(number: ticket.number)
                    .frame(height: 230)
                    .accessibilityHidden(true)

                Text(String(format: s.successTitle, ticket.number))
                    .font(style.font(.title, .bold))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("faro.success.number")

                let message = model.shownForm.successMessage
                Text(message.isEmpty ? s.successDefault : message)
                    .font(style.font(.body))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if !ticket.email.isEmpty {
                    VStack(spacing: 8) {
                        Text(String(format: s.successReplies, ticket.email, ticket.number))
                        if !ticket.isConfirmed {
                            Label(s.successConfirm, systemImage: "envelope.badge")
                        }
                    }
                    .font(style.font(.footnote))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    if let onClose {
                        Button(action: onClose) {
                            Text(s.done)
                                .font(style.font(.headline))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .foregroundStyle(style.onAccent)
                                .background(style.control().fill(style.accent))
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityIdentifier("faro.done")
                    }
                    Button {
                        withAnimation { model.startOver() }
                    } label: {
                        Text(s.sendAnother)
                            .font(style.font(.headline))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(style.accentInk)
                            .background(style.control().fill(style.accent.opacity(0.12)))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityIdentifier("faro.sendAnother")
                }
                .padding(.top, 8)
            }
            .padding(20)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
    }
}

/**
 A lighthouse at night: rings spreading from the lamp and a beam turning
 around it, with the request number on the lamp. Still when Reduce Motion is on.
 */
struct LighthouseBeam: View {
    let number: Int

    @Environment(\.faroStyle) private var style
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        Group {
            if reduceMotion {
                scene(time: 0.6)
            } else {
                TimelineView(.animation) { context in
                    scene(time: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .scaleEffect(appeared ? 1 : 0.6)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { appeared = true }
        }
    }

    private func scene(time: TimeInterval) -> some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let reach = max(size.width, size.height) * 0.75

                // The beam: a wedge turning once every 6 s, brightest at the lamp.
                let angle = Angle.degrees((time * 60).truncatingRemainder(dividingBy: 360))
                for (offset, spread) in [(0.0, 26.0), (180.0, 16.0)] {
                    var wedge = Path()
                    wedge.move(to: center)
                    wedge.addArc(
                        center: center, radius: reach,
                        startAngle: angle + .degrees(offset - spread / 2),
                        endAngle: angle + .degrees(offset + spread / 2),
                        clockwise: false
                    )
                    wedge.closeSubpath()
                    context.fill(wedge, with: .radialGradient(
                        Gradient(colors: [style.accent.opacity(offset == 0 ? 0.55 : 0.25), style.accent.opacity(0)]),
                        center: center, startRadius: 30, endRadius: reach
                    ))
                }

                // Rings spreading out, like light over water.
                for i in 0..<3 {
                    let progress = ((time / 2.4) + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    let radius = 52 + progress * 70
                    let ring = Path(ellipseIn: CGRect(
                        x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2
                    ))
                    context.stroke(ring, with: .color(style.accent.opacity(0.35 * (1 - progress))), lineWidth: 1.5)
                }
            }

            Circle()
                .fill(style.accent)
                .frame(width: 104, height: 104)
                .shadow(color: style.accent.opacity(0.55), radius: 22)
                .overlay(
                    Text("#\(number)")
                        .font(.system(size: number > 9999 ? 22 : 28, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(style.onAccent)
                        .minimumScaleFactor(0.5)
                        .padding(10)
                )
        }
    }
}
#endif
