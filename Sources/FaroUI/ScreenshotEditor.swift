#if canImport(UIKit) && os(iOS)
import SwiftUI
import UIKit

/// A color stored as sRGB components, so a stroke stays `Sendable` and `Hashable`.
struct InkColor: Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    /// The opaque, near-black marker. It hides what is under it for good.
    static let cover = InkColor(red: 0.07, green: 0.07, blue: 0.07)

    /// `color` as it looks on the editor's dark backdrop.
    init(_ color: Color) {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if resolved.getRed(&r, green: &g, blue: &b, alpha: &a) {
            self.init(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
        } else {
            self.init(red: 1, green: 0.66, blue: 0.2)
        }
    }

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }
    var cgColor: CGColor { CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }
}

/**
 A mark over the screenshot: a thick marker or a filled box that cover what is
 under them, or a thin pen in the accent color to point something out. Points
 are fractions of the image (0…1 on each axis) and the width a fraction of its
 width, so the same mark draws on the small preview and on the full-size capture.
 */
struct RedactionStroke: Hashable, Sendable {
    enum Tool: Hashable, Sendable, CaseIterable {
        /// The thick marker.
        case cover
        /// A filled rectangle from where the finger went down to where it is.
        case box
        /// The thin pen.
        case mark
    }

    var tool: Tool = .cover
    var points: [CGPoint]
    var width: CGFloat
    var ink: InkColor = .cover

    /// The line of a marker or pen stroke; the rectangle of a box.
    func path(in size: CGSize) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        func scaled(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x * size.width, y: point.y * size.height) }
        if tool == .box {
            let a = scaled(first), b = scaled(points.last ?? first)
            path.addRect(CGRect(
                x: min(a.x, b.x), y: min(a.y, b.y),
                width: max(abs(b.x - a.x), 2), height: max(abs(b.y - a.y), 2)
            ))
            return path
        }
        path.move(to: scaled(first))
        // A tap still leaves a dot: a zero-length segment gets round caps.
        for point in points.count == 1 ? points : Array(points.dropFirst()) {
            path.addLine(to: scaled(point))
        }
        return path
    }

    /// The image with the marks burned in, at its full size.
    static func render(_ strokes: [RedactionStroke], over image: UIImage) -> UIImage {
        guard !strokes.isEmpty else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: image.size, format: format).image { context in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let cg = context.cgContext
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            for stroke in strokes {
                cg.addPath(stroke.path(in: image.size).cgPath)
                if stroke.tool == .box {
                    cg.setFillColor(stroke.ink.cgColor)
                    cg.fillPath()
                } else {
                    cg.setStrokeColor(stroke.ink.cgColor)
                    cg.setLineWidth(stroke.width * image.size.width)
                    cg.strokePath()
                }
            }
        }
    }
}

/**
 Full-screen editor to cover private data on the screenshot: a thick marker
 (in three sizes) and boxes to cover names, numbers or faces, and a thin pen in
 the accent color to point at what went wrong; undo and start over. The marks
 come back to the caller, who burns them into the image (the original is kept,
 so the next visit can still undo them).
 */
struct ScreenshotEditor: View {
    let image: UIImage
    let strings: FaroStrings
    let onDone: ([RedactionStroke]) -> Void

    @State private var strokes: [RedactionStroke]
    @State private var current: RedactionStroke?
    @State private var tool: RedactionStroke.Tool = .cover
    @State private var size: CGFloat = 0.06
    @Environment(\.dismiss) private var dismiss
    @Environment(\.faroStyle) private var style

    private static let sizes: [CGFloat] = [0.03, 0.06, 0.11]
    /// The pen: thin, a fraction of the image width.
    private static let penWidth: CGFloat = 0.012

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
                    for stroke in strokes + (current.map { [$0] } ?? []) {
                        let path = stroke.path(in: canvasSize)
                        if stroke.tool == .box {
                            context.fill(path, with: .color(stroke.ink.color))
                        } else {
                            context.stroke(
                                path,
                                with: .color(stroke.ink.color),
                                style: StrokeStyle(lineWidth: stroke.width * canvasSize.width, lineCap: .round, lineJoin: .round)
                            )
                        }
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
                            current = newStroke(at: point)
                        } else if tool == .box {
                            current?.points = [current?.points.first ?? point, point]
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

    private func newStroke(at point: CGPoint) -> RedactionStroke {
        switch tool {
        case .cover: return RedactionStroke(tool: .cover, points: [point], width: size)
        case .box: return RedactionStroke(tool: .box, points: [point, point], width: 0)
        case .mark: return RedactionStroke(tool: .mark, points: [point], width: Self.penWidth, ink: InkColor(style.accent))
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Text(strings.editorHint)
                .font(style.font(.footnote))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                ForEach(RedactionStroke.Tool.allCases, id: \.self) { option in
                    ToolButton(
                        symbol: symbol(option), label: label(option), selected: tool == option, accent: style.accent
                    ) {
                        tool = option
                    }
                    .accessibilityIdentifier("faro.editor.tool.\(option)")
                }
                Spacer(minLength: 4)
                Button {
                    _ = strokes.popLast()
                } label: {
                    Label(strings.undo, systemImage: "arrow.uturn.backward")
                        .frame(width: 44, height: 44)
                }
                .disabled(strokes.isEmpty)
                .accessibilityIdentifier("faro.editor.undo")
                Button {
                    strokes.removeAll()
                } label: {
                    Label(strings.clear, systemImage: "trash")
                        .frame(width: 44, height: 44)
                }
                .disabled(strokes.isEmpty)
            }
            .labelStyle(.iconOnly)
            .imageScale(.large)
            .foregroundStyle(.white)
            if tool == .cover {
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
                        .accessibilityLabel(Text("\(strings.toolCover) \(Int(option * 100))%"))
                        .accessibilityAddTraits(size == option ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: tool)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func symbol(_ tool: RedactionStroke.Tool) -> String {
        switch tool {
        case .cover: return "scribble.variable"
        case .box: return "rectangle.fill"
        case .mark: return "pencil.tip"
        }
    }

    private func label(_ tool: RedactionStroke.Tool) -> String {
        switch tool {
        case .cover: return strings.toolCover
        case .box: return strings.toolBox
        case .mark: return strings.toolMark
        }
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

/// A tool of the editor: its icon over its name, tinted when chosen.
private struct ToolButton: View {
    let symbol: String
    let label: String
    let selected: Bool
    let accent: Color
    let action: () -> Void

    @Environment(\.faroStyle) private var style

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                Text(label)
                    .font(style.font(.caption2, .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(selected ? accent : Color.white)
            .frame(width: 70, height: 54)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? accent.opacity(0.22) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
#endif
