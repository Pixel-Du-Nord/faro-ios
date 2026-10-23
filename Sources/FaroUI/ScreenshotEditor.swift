#if canImport(UIKit) && os(iOS)
import SwiftUI
import UIKit

/**
 A marker stroke over the screenshot. Points are fractions of the image
 (0…1 on each axis) and the width a fraction of its width, so the same stroke
 draws on the small preview and on the full-size capture.
 */
struct RedactionStroke: Hashable, Sendable {
    var points: [CGPoint]
    var width: CGFloat

    /// The ink: an opaque, near-black marker. It hides what is under it for good.
    static let ink = UIColor(white: 0.07, alpha: 1)

    func path(in size: CGSize) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
        // A tap still leaves a dot: a zero-length segment gets round caps.
        for point in points.count == 1 ? points : Array(points.dropFirst()) {
            path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
        }
        return path
    }

    /// The image with the strokes burned in, at its full size.
    static func render(_ strokes: [RedactionStroke], over image: UIImage) -> UIImage {
        guard !strokes.isEmpty else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: image.size, format: format).image { context in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let cg = context.cgContext
            cg.setStrokeColor(ink.cgColor)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            for stroke in strokes {
                cg.setLineWidth(stroke.width * image.size.width)
                cg.addPath(stroke.path(in: image.size).cgPath)
                cg.strokePath()
            }
        }
    }
}

/**
 Full-screen editor to cover private data on the screenshot: draw with a
 finger, choose the marker size, undo, start over. Strokes come back to the
 caller, who burns them into the image (the original is kept, so the next
 visit can still undo them).
 */
struct ScreenshotEditor: View {
    let image: UIImage
    let strings: FaroStrings
    let onDone: ([RedactionStroke]) -> Void

    @State private var strokes: [RedactionStroke]
    @State private var current: RedactionStroke?
    @State private var size: CGFloat = 0.06
    @Environment(\.dismiss) private var dismiss
    @Environment(\.faroStyle) private var style

    private static let sizes: [CGFloat] = [0.03, 0.06, 0.11]

    init(image: UIImage, strokes: [RedactionStroke], strings: FaroStrings, onDone: @escaping ([RedactionStroke]) -> Void) {
        self.image = image
        self.strings = strings
        self.onDone = onDone
        _strokes = State(initialValue: strokes)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            GeometryReader { geometry in
                let frame = fitted(image.size, in: geometry.size)
                canvas(size: frame.size)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            bottomBar
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    private var topBar: some View {
        HStack {
            Button(strings.cancel) { dismiss() }
                .accessibilityIdentifier("faro.editor.cancel")
            Spacer()
            Text(strings.coverPrivate)
                .font(style.font(.headline))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button {
                onDone(strokes)
                dismiss()
            } label: {
                Text(strings.done).fontWeight(.semibold)
            }
            .accessibilityIdentifier("faro.editor.done")
        }
        .font(style.font(.body))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func canvas(size: CGSize) -> some View {
        Image(uiImage: image)
            .resizable()
            .overlay(
                Canvas { context, canvasSize in
                    let ink = Color(RedactionStroke.ink)
                    for stroke in strokes + (current.map { [$0] } ?? []) {
                        context.stroke(
                            stroke.path(in: canvasSize),
                            with: .color(ink),
                            style: StrokeStyle(lineWidth: stroke.width * canvasSize.width, lineCap: .round, lineJoin: .round)
                        )
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let point = CGPoint(
                            x: min(max(value.location.x / size.width, 0), 1),
                            y: min(max(value.location.y / size.height, 0), 1)
                        )
                        if current == nil {
                            current = RedactionStroke(points: [point], width: self.size)
                        } else {
                            current?.points.append(point)
                        }
                    }
                    .onEnded { _ in
                        if let current { strokes.append(current) }
                        current = nil
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(strings.editorCanvas)
            .accessibilityAddTraits(.allowsDirectInteraction)
            .accessibilityIdentifier("faro.editor.canvas")
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            Text(strings.editorHint)
                .font(style.font(.footnote))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            HStack(spacing: 22) {
                Button {
                    _ = strokes.popLast()
                } label: {
                    Label(strings.undo, systemImage: "arrow.uturn.backward")
                }
                .disabled(strokes.isEmpty)
                .accessibilityIdentifier("faro.editor.undo")

                HStack(spacing: 14) {
                    ForEach(Self.sizes, id: \.self) { option in
                        Button {
                            size = option
                        } label: {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8 + option * 140, height: 8 + option * 140)
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Circle()
                                        .strokeBorder(size == option ? style.accent : Color.clear, lineWidth: 2)
                                )
                        }
                        .accessibilityLabel(Text("\(Int(option * 100))%"))
                        .accessibilityAddTraits(size == option ? [.isButton, .isSelected] : .isButton)
                    }
                }

                Button {
                    strokes.removeAll()
                } label: {
                    Label(strings.clear, systemImage: "trash")
                }
                .disabled(strokes.isEmpty)
            }
            .font(style.font(.subheadline, .semibold))
            .labelStyle(.iconOnly)
            .foregroundStyle(.white)
            .imageScale(.large)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    /// The largest rectangle with the image's proportions that fits `space`, centered.
    private func fitted(_ image: CGSize, in space: CGSize) -> CGRect {
        guard image.width > 0, image.height > 0 else { return CGRect(origin: .zero, size: space) }
        let scale = min(space.width / image.width, space.height / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(
            x: (space.width - size.width) / 2, y: (space.height - size.height) / 2,
            width: size.width, height: size.height
        )
    }
}
#endif
