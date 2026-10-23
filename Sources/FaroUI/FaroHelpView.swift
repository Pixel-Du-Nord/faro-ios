#if canImport(UIKit) && os(iOS)
import Faro
import SwiftUI
import UIKit

/**
 A ready-made "Help & feedback" screen, drawn from the form defined in the
 Faro panel: the request kinds, the organization's fields in their order, a
 screenshot of the previous screen (which the person can draw over to cover
 private data), photos from their library, and the send button.

 It handles loading (the cached form shows instantly), no network, errors next
 to the right field, sending, and success with the request number. Texts Faro
 does not send are in English, Spanish and Portuguese.

 ```swift
 // Capture before presenting, so the screenshot shows what the person was looking at.
 Button("Help") {
     screenshot = FaroScreenshot.captureKeyWindow()
     showHelp = true
 }
 .sheet(isPresented: $showHelp) {
     FaroHelpView(screenshot: screenshot) { showHelp = false }
 }
 ```

 Or let ``SwiftUI/View/faroHelpSheet(isPresented:faro:locale:captureScreenshot:prefill:device:onSent:)``
 do the capture and the sheet for you.
 */
public struct FaroHelpView: View {
    @StateObject private var model: HelpModel
    @Environment(\.faroTheme) private var theme
    private let onSent: ((FaroTicket) -> Void)?
    private let onClose: (() -> Void)?

    /**
     - Parameters:
       - faro: The client to use. ``Faro/shared`` by default.
       - locale: The language for the form and the screen. `nil` uses the configured one, then the device's.
       - screenshot: A capture of the previous screen (``FaroScreenshot/captureKeyWindow()``),
         offered as the first attachment. The person can cover parts of it or leave it out.
       - prefill: Values to start with (a kind, a field…).
       - device: Extra device facts of your own (`["plan": "pro"]`). Never secrets or personal data.
       - onSent: Called once the request is in.
       - onClose: Shows a close button and is called when it is tapped (and on "Done" after sending).
     */
    public init(
        faro: Faro = .shared,
        locale: String? = nil,
        screenshot: UIImage? = nil,
        prefill: FaroPrefill = FaroPrefill(),
        device: [String: String] = [:],
        onSent: ((FaroTicket) -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        _model = StateObject(wrappedValue: HelpModel(
            faro: faro, locale: locale, screenshot: screenshot, prefill: prefill, device: device
        ))
        self.onSent = onSent
        self.onClose = onClose
    }

    public var body: some View {
        let style = FaroStyle(theme: theme, brandColor: model.form?.brandColor)
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            if model.phase == .sent, let ticket = model.ticket {
                SuccessView(model: model, ticket: ticket, onClose: onClose)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if model.form == nil && model.link == .offline {
                OfflineView(model: model, onClose: onClose)
                    .transition(.opacity)
            } else {
                HelpFormView(model: model, onClose: onClose)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: model.phase == .sent)
        .environment(\.faroStyle, style)
        .tint(style.accentInk)
        .task { model.start() }
        .onChange(of: model.ticket) { ticket in
            if let ticket { onSent?(ticket) }
        }
    }
}

// MARK: - The form

struct HelpFormView: View {
    @ObservedObject var model: HelpModel
    let onClose: (() -> Void)?

    @Environment(\.faroStyle) private var style
    @Environment(\.dynamicTypeSize) private var typeSize
    @FocusState private var focused: String?
    @State private var editingScreenshot = false
    @State private var showingDetails = false

    private var s: FaroStrings { model.strings }

    var body: some View {
        let form = model.shownForm
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header(form)
                    Group {
                        if form.kinds.count > 1 { kindSection(form).id(FaroForm.kindKey) }
                        fieldsCard(form)
                        attachmentsCard
                        detailsSection
                        sendSection(form)
                    }
                    .redacted(reason: model.isLoadingFirstTime ? .placeholder : [])
                    .disabled(model.isLoadingFirstTime)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .modifier(DismissKeyboardOnScroll())
            .onChange(of: model.issueRound) { _ in
                let keys = [FaroForm.kindKey] + form.fields.map(\.key)
                guard let first = keys.first(where: { model.issues[$0] != nil }) else { return }
                withAnimation(.easeInOut(duration: 0.3)) { reader.scrollTo(first, anchor: .top) }
                if first != FaroForm.kindKey, form.field(first)?.type != .select { focused = first }
            }
        }
        .fullScreenCover(isPresented: $editingScreenshot) {
            if let original = model.originalScreenshot {
                ScreenshotEditor(image: original, strokes: model.strokes, strings: s) { strokes in
                    model.applyStrokes(strokes)
                }
                .environment(\.faroStyle, style)
            }
        }
    }

    // MARK: Header

    private func header(_ form: FaroForm) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text(form.title.isEmpty ? s.helpTitle : form.title)
                    .font(style.font(.title, .bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                if let onClose {
                    CloseButton(label: s.close, action: onClose)
                }
            }
            Text(form.intro.isEmpty ? s.defaultIntro : form.intro)
                .font(style.font(.subheadline))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            BeamLine(link: model.link)
                .padding(.top, 4)
            switch model.link {
            case .connecting:
                Text(s.statusConnecting)
                    .font(style.font(.caption))
                    .foregroundStyle(.secondary)
            case .cached:
                Button(action: model.load) {
                    Label(s.statusCached, systemImage: "arrow.clockwise")
                        .font(style.font(.caption))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            case .live, .offline:
                EmptyView()
            }
        }
    }

    // MARK: Kind

    private func kindSection(_ form: FaroForm) -> some View {
        let issue = model.issues[FaroForm.kindKey]
        return VStack(alignment: .leading, spacing: 10) {
            Text(s.kindHeading)
                .font(style.font(.headline))
                .accessibilityAddTraits(.isHeader)
            if typeSize.isAccessibilitySize {
                VStack(spacing: 8) { kindTiles(form, issue: issue != nil) }
            } else {
                HStack(spacing: 8) { kindTiles(form, issue: issue != nil) }
            }
            Group {
                if let issue {
                    Label(s.issue(issue, key: FaroForm.kindKey), systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                } else if let kind = model.kind {
                    Text(s.kindHint(kind)).foregroundStyle(.secondary)
                } else {
                    Text(s.kindPrompt).foregroundStyle(.secondary)
                }
            }
            .font(style.font(.footnote))
        }
    }

    @ViewBuilder
    private func kindTiles(_ form: FaroForm, issue: Bool) -> some View {
        ForEach(form.kinds, id: \.self) { kind in
            KindTile(
                kind: kind,
                name: s.kindName(kind),
                hint: s.kindHint(kind),
                selected: model.kind == kind,
                hasIssue: issue,
                horizontal: typeSize.isAccessibilitySize
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { model.choose(kind) }
            }
        }
    }

    // MARK: Fields

    private func fieldsCard(_ form: FaroForm) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(form.fields.enumerated()), id: \.element.key) { index, field in
                if index > 0 { Divider().padding(.leading, 14) }
                FieldRow(field: field, model: model, focused: $focused) {
                    // Return moves to the next text field.
                    let next = form.fields.dropFirst(index + 1).first { $0.type.isTyped }
                    focused = next?.key
                }
                .id(field.key)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: style.cardRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: Attachments

    private var attachmentsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(s.attachmentsHeading)
                    .font(style.font(.headline))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(String(format: s.attachmentsCount, model.attachedCount, FaroAttachment.maxCount))
                    .font(style.font(.caption).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let shot = model.screenshot {
                ScreenshotCard(
                    image: shot,
                    included: Binding(get: { model.includeScreenshot }, set: { model.includeScreenshot = $0 }),
                    canInclude: model.includeScreenshot || model.photos.count < FaroAttachment.maxCount,
                    strings: s
                ) {
                    editingScreenshot = true
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(model.photos) { photo in
                        PhotoTile(image: photo.preview, removeLabel: s.removeImage) { model.remove(photo) }
                    }
                    if model.roomForPhotos > 0 {
                        PhotoPickerButton(limit: model.roomForPhotos, label: s.addPhotos) { model.attach($0) }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: style.cardRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: What travels with the request

    private var detailsSection: some View {
        DisclosureGroup(isExpanded: $showingDetails) {
            VStack(alignment: .leading, spacing: 10) {
                Text(s.sentWithDetail)
                    .font(style.font(.footnote))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(model.deviceFacts, id: \.key) { fact in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(fact.key)
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 92, alignment: .leading)
                            Text(fact.value)
                                .foregroundStyle(.primary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .font(.system(.caption, design: .monospaced))
                let crumbs = Faro.breadcrumbs
                if !crumbs.isEmpty {
                    Text("\(s.recentActions) · \(crumbs.count)")
                        .font(style.font(.footnote, .semibold))
                        .padding(.top, 4)
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(crumbs.suffix(8).enumerated()), id: \.offset) { _, crumb in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Circle().fill(style.accent).frame(width: 5, height: 5)
                                Text(crumb.message)
                            }
                        }
                    }
                    .font(style.font(.caption))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(s.sentWith, systemImage: "shippingbox")
                .font(style.font(.subheadline, .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Send

    private func sendSection(_ form: FaroForm) -> some View {
        let sending = model.phase == .sending
        let notice = form.acceptsRequests ? model.notice : .unavailable
        return VStack(spacing: 12) {
            if let notice {
                NoticeBanner(notice: notice, strings: s)
            }
            Button(action: {
                focused = nil
                model.send()
            }) {
                HStack(spacing: 10) {
                    if sending {
                        ProgressView().tint(style.onAccent)
                        Text(s.sending)
                    } else {
                        Image(systemName: "paperplane.fill")
                        Text(form.submitLabel.isEmpty ? s.send : form.submitLabel)
                    }
                }
                .font(style.font(.headline))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(style.onAccent)
                .background(style.control().fill(style.accent))
            }
            .buttonStyle(PressableStyle())
            .disabled(sending || !form.acceptsRequests)
            .opacity(form.acceptsRequests ? 1 : 0.5)
            .accessibilityIdentifier("faro.send")
        }
    }
}

extension FaroFieldType {
    /// Fields typed with the keyboard (Return moves between them).
    var isTyped: Bool {
        switch self {
        case .text, .email, .number, .tel, .url, .textarea: return true
        case .select, .checkbox, .date: return false
        }
    }
}

// MARK: - Pieces

/// The kind as a tile: an icon in a disc over its name.
private struct KindTile: View {
    let kind: FaroKind
    let name: String
    let hint: String
    let selected: Bool
    let hasIssue: Bool
    let horizontal: Bool
    let action: () -> Void

    @Environment(\.faroStyle) private var style

    private var symbol: String {
        switch kind {
        case .problem: return "ladybug.fill"
        case .suggestion: return "lightbulb.fill"
        case .question: return "questionmark.bubble.fill"
        default: return "tag.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            let icon = Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .frame(width: 42, height: 42)
                .foregroundStyle(selected ? style.onAccent : style.accentInk)
                .background(Circle().fill(selected ? style.onAccent.opacity(0.16) : style.accent.opacity(0.13)))
                .scaleEffect(selected ? 1.08 : 1)
            let label = Text(name)
                .font(style.font(.footnote, .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Group {
                if horizontal {
                    HStack(spacing: 12) {
                        icon
                        label
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                } else {
                    VStack(spacing: 8) {
                        icon
                        label.multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity, minHeight: 96)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 6)
                }
            }
            .foregroundStyle(selected ? style.onAccent : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: style.fieldRadius + 4, style: .continuous)
                    .fill(selected ? AnyShapeStyle(style.accent) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: style.fieldRadius + 4, style: .continuous)
                    .strokeBorder(hasIssue ? Color.red.opacity(0.8) : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityHint(hint)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("faro.kind.\(kind.rawValue)")
    }
}

/// The capture of the previous screen: a phone-shaped preview, the button to
/// cover private data, and whether it goes with the request.
private struct ScreenshotCard: View {
    let image: UIImage
    @Binding var included: Bool
    let canInclude: Bool
    let strings: FaroStrings
    let onEdit: () -> Void

    @Environment(\.faroStyle) private var style

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: onEdit) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 104, maxHeight: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                    .opacity(included ? 1 : 0.35)
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(strings.screenshotPreview)
            .accessibilityHint(strings.coverPrivate)

            VStack(alignment: .leading, spacing: 10) {
                Text(strings.screenshotCaption)
                    .font(style.font(.footnote))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onEdit) {
                    Label(strings.coverPrivate, systemImage: "scribble")
                        .font(style.font(.subheadline, .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(style.control().fill(style.accent.opacity(0.14)))
                        .foregroundStyle(style.accentInk)
                }
                .buttonStyle(PressableStyle())
                .disabled(!included)
                .accessibilityIdentifier("faro.screenshot.edit")
                Toggle(isOn: $included) {
                    Text(included ? strings.screenshotIncluded : strings.screenshotExcluded)
                        .font(style.font(.footnote))
                }
                .toggleStyle(SwitchToggleStyle(tint: style.accent))
                .disabled(!canInclude)
                .accessibilityIdentifier("faro.screenshot.include")
            }
        }
    }
}

private struct PhotoTile: View {
    let image: UIImage
    let removeLabel: String
    let onRemove: () -> Void

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 78, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.65))
                        .font(.title3)
                }
                .offset(x: 7, y: -7)
                .accessibilityLabel(removeLabel)
            }
    }
}

private struct NoticeBanner: View {
    let notice: HelpModel.Notice
    let strings: FaroStrings

    @Environment(\.faroStyle) private var style

    var body: some View {
        let (symbol, text, color): (String, String, Color) = {
            switch notice {
            case .offline: return ("wifi.slash", strings.noticeOffline, .red)
            case .rateLimited: return ("hourglass", strings.noticeRateLimited, .orange)
            case .failed: return ("exclamationmark.triangle.fill", strings.noticeFailed, .red)
            case .attachment: return ("photo", strings.noticeAttachment, .orange)
            case .unavailable: return ("lock.fill", strings.noticeUnavailable, .secondary)
            }
        }()
        Label(text, systemImage: symbol)
            .font(style.font(.footnote))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: style.fieldRadius, style: .continuous)
                    .fill(color.opacity(0.1))
            )
            .accessibilityElement(children: .combine)
    }
}

struct CloseButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color(.tertiarySystemFill)))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier("faro.close")
    }
}

/// A gentle press: buttons sink a little while held.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/**
 The lighthouse beam under the header: it sweeps while the form is loading,
 burns steady once Faro answered, and dims on the cached copy.
 */
struct BeamLine: View {
    let link: HelpModel.Link

    @Environment(\.faroStyle) private var style
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.07))
                switch link {
                case .connecting:
                    if reduceMotion {
                        Capsule().fill(style.accent.opacity(0.5)).frame(width: width * 0.3)
                    } else {
                        TimelineView(.animation) { context in
                            let t = context.date.timeIntervalSinceReferenceDate
                            let phase = (sin(t * 2.2) + 1) / 2
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [style.accent.opacity(0), style.accent, style.accent.opacity(0)],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: width * 0.38)
                                .offset(x: phase * width * 0.62)
                        }
                    }
                case .live:
                    Capsule()
                        .fill(LinearGradient(
                            colors: [style.accent.opacity(0.9), style.accent.opacity(0.15)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                case .cached:
                    Capsule().fill(style.accent.opacity(0.4)).frame(width: width * 0.55)
                case .offline:
                    EmptyView()
                }
            }
        }
        .frame(height: 3)
        .animation(.easeInOut(duration: 0.5), value: link)
        .accessibilityHidden(true)
    }
}

/// Drags on the scroll view put the keyboard away (iOS 16+; earlier, Return does).
private struct DismissKeyboardOnScroll: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollDismissesKeyboard(.interactively)
        } else {
            content
        }
    }
}

// MARK: - No network, nothing cached

struct OfflineView: View {
    @ObservedObject var model: HelpModel
    let onClose: (() -> Void)?

    @Environment(\.faroStyle) private var style

    var body: some View {
        VStack(spacing: 18) {
            if let onClose {
                HStack {
                    Spacer()
                    CloseButton(label: model.strings.close, action: onClose)
                }
            }
            Spacer()
            ZStack {
                Circle().fill(style.accent.opacity(0.12)).frame(width: 96, height: 96)
                Image(systemName: "wifi.slash")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(style.accentInk)
            }
            .accessibilityHidden(true)
            Text(model.strings.offlineTitle)
                .font(style.font(.title2, .bold))
                .accessibilityAddTraits(.isHeader)
            Text(model.strings.offlineBody)
                .font(style.font(.body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: model.load) {
                Label(model.strings.retry, systemImage: "arrow.clockwise")
                    .font(style.font(.headline))
                    .padding(.horizontal, 26)
                    .padding(.vertical, 13)
                    .foregroundStyle(style.onAccent)
                    .background(style.control().fill(style.accent))
            }
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier("faro.retry")
            Spacer()
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }
}
#endif
