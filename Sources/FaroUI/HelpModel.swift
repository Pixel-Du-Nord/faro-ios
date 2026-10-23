#if canImport(UIKit) && os(iOS)
import Faro
import SwiftUI
import UIKit

/// Values to open ``FaroHelpView`` with: a preselected kind, a field already answered…
public struct FaroPrefill: Sendable, Hashable {
    /// The kind to select, if the form offers it.
    public var kind: FaroKind?
    /// The start of the message.
    public var message: String?
    /// The email, when you know it and did not call ``Faro/identify(_:)``.
    public var email: String?
    /// The name, when you know it and did not call ``Faro/identify(_:)``.
    public var name: String?
    /// The organization's own fields, by key (`["where": "shop"]`).
    public var fields: [String: String]

    public init(
        kind: FaroKind? = nil,
        message: String? = nil,
        email: String? = nil,
        name: String? = nil,
        fields: [String: String] = [:]
    ) {
        self.kind = kind
        self.message = message
        self.email = email
        self.name = name
        self.fields = fields
    }
}

/**
 The brain of ``FaroHelpView``.

 On start it does two things at once, so everything is ready by the time the
 person finishes typing: shows the cached form while fetching the fresh one,
 and prepares the proof of work (which Faro rejects before 3 s).

 `values` holds everything typed by Faro key (`name`, `email`, `message` and
 the organization's own), so the screen walks the form without knowing its
 fields in advance.
 */
@MainActor
final class HelpModel: ObservableObject {
    enum Phase { case editing, sending, sent }
    enum Link { case connecting, live, cached, offline }
    enum Notice: Equatable { case offline, rateLimited, failed, attachment, unavailable }

    struct Photo: Identifiable {
        let id = UUID()
        let attachment: FaroAttachment
        let preview: UIImage
    }

    @Published private(set) var form: FaroForm?
    @Published private(set) var link: Link = .connecting
    @Published var kind: FaroKind?
    @Published private(set) var values: [String: String] = [:]
    @Published private(set) var issues: [String: FaroFieldIssue] = [:]
    /// Bumped on every failed attempt, so the screen scrolls to the first issue.
    @Published private(set) var issueRound = 0
    @Published var notice: Notice?
    @Published private(set) var phase: Phase = .editing
    @Published private(set) var ticket: FaroTicket?
    /// The capture of the previous screen, with whatever was covered.
    @Published private(set) var screenshot: UIImage?
    /// The capture as it was taken, and the strokes drawn over it.
    private(set) var originalScreenshot: UIImage?
    private(set) var strokes: [RedactionStroke] = []
    @Published var includeScreenshot = true
    @Published private(set) var photos: [Photo] = []

    let faro: Faro
    let language: String
    let strings: FaroStrings
    private let prefill: FaroPrefill
    private let extraDevice: [String: String]
    private var started = false
    private var sendTask: Task<Void, Never>?

    private static let emailKey = "com.pixeldunord.faro.lastEmail"
    private static let nameKey = "com.pixeldunord.faro.lastName"

    init(faro: Faro, locale: String?, screenshot: UIImage?, prefill: FaroPrefill, device: [String: String]) {
        self.faro = faro
        self.language = FaroLocale.language(locale ?? faro.configuration.locale)
        self.strings = FaroStrings.forLanguage(language)
        self.screenshot = screenshot
        self.originalScreenshot = screenshot
        self.prefill = prefill
        self.extraDevice = device
    }

    /// The form on screen: Faro's, the cached one, or the built-in fallback while loading.
    var shownForm: FaroForm { form ?? .fallback(locale: language) }

    var isLoadingFirstTime: Bool { form == nil && link == .connecting }

    /// How many more images fit (Faro takes 3, the screenshot included).
    var roomForPhotos: Int {
        FaroAttachment.maxCount - photos.count - (screenshot != nil && includeScreenshot ? 1 : 0)
    }

    var attachedCount: Int { photos.count + (screenshot != nil && includeScreenshot ? 1 : 0) }

    func start() {
        guard !started else { return }
        started = true
        form = faro.cachedForm(locale: language)
        link = form == nil ? .connecting : .cached
        let user = Faro.currentUser
        let defaults = UserDefaults.standard
        let email = prefill.email ?? user?.email ?? defaults.string(forKey: Self.emailKey)
        let name = prefill.name ?? user?.name ?? defaults.string(forKey: Self.nameKey)
        if let email, !email.isEmpty { values[FaroFormField.emailKey] = email }
        if let name, !name.isEmpty { values[FaroFormField.nameKey] = name }
        if let message = prefill.message { values[FaroFormField.messageKey] = message }
        for (key, value) in prefill.fields { values[key] = value }
        kind = prefill.kind
        faro.prepare()
        load()
    }

    func load() {
        if form == nil { link = .connecting }
        Task {
            do {
                let fresh = try await faro.form(locale: language)
                form = fresh
                link = fresh.source == .network ? .live : .cached
                if kind.map({ !fresh.kinds.contains($0) }) ?? false { kind = nil }
                if fresh.kinds.count == 1 { kind = fresh.kinds[0] }
                faro.prepare()
            } catch {
                link = form == nil ? .offline : .cached
            }
        }
    }

    func value(_ key: String) -> String { values[key] ?? "" }

    func set(_ key: String, _ value: String) {
        values[key] = value
        if issues[key] != nil { issues[key] = nil }
    }

    func choose(_ newKind: FaroKind) {
        kind = newKind
        issues[FaroForm.kindKey] = nil
    }

    // MARK: Images

    func attach(_ items: [Data]) {
        let room = roomForPhotos
        guard room > 0, !items.isEmpty else { return }
        let batch = Array(items.prefix(room))
        Task {
            let prepared = await Task.detached(priority: .userInitiated) { () -> [(FaroAttachment, UIImage)?] in
                batch.map { data in
                    guard let attachment = try? FaroAttachment(imageData: data, filename: "photo.jpg"),
                          let preview = UIImage(data: attachment.data) else { return nil }
                    return (attachment, preview)
                }
            }.value
            let added = prepared.compactMap { $0 }.map { Photo(attachment: $0.0, preview: $0.1) }
            photos = Array((photos + added).prefix(FaroAttachment.maxCount))
            notice = added.count < batch.count ? .attachment : (notice == .attachment ? nil : notice)
        }
    }

    /// Redraws the screenshot with the strokes from the editor.
    func applyStrokes(_ strokes: [RedactionStroke]) {
        guard let original = originalScreenshot else { return }
        self.strokes = strokes
        screenshot = RedactionStroke.render(strokes, over: original)
    }

    /// What travels as device facts, sorted for display.
    var deviceFacts: [(key: String, value: String)] {
        Faro.deviceFacts(adding: extraDevice).sorted { $0.key < $1.key }
    }

    func remove(_ photo: Photo) {
        photos.removeAll { $0.id == photo.id }
        if notice == .attachment { notice = nil }
    }

    // MARK: Sending

    func send() {
        guard phase != .sending else { return }
        let form = shownForm
        let found = form.validate(kind: kind, values: values)
        guard found.isEmpty, let kind else {
            issues = found
            notice = nil
            issueRound += 1
            return
        }
        phase = .sending
        notice = nil
        issues = [:]
        let shot = includeScreenshot ? screenshot : nil
        let photos = self.photos.map(\.attachment)
        var request = form.request(kind: kind, values: values)
        request.locale = language
        request.device = extraDevice
        sendTask = Task {
            do {
                var attachments: [FaroAttachment] = []
                if let shot {
                    attachments.append(try await Task.detached(priority: .userInitiated) {
                        try FaroAttachment(image: shot, filename: "screenshot.jpg")
                    }.value)
                }
                request.attachments = attachments + photos
                let ticket = try await faro.send(request)
                remember(email: request.email, name: request.name)
                self.ticket = ticket
                phase = .sent
                UIAccessibility.post(notification: .screenChanged, argument: nil)
            } catch let error as FaroError {
                phase = .editing
                apply(error)
            } catch is CancellationError {
                phase = .editing
            } catch {
                phase = .editing
                notice = .failed
            }
        }
    }

    /// After a request is in: another one, keeping the name and email.
    func startOver() {
        let keep = values.filter { $0.key == FaroFormField.nameKey || $0.key == FaroFormField.emailKey }
        values = keep
        kind = shownForm.kinds.count == 1 ? shownForm.kinds[0] : nil
        photos = []
        screenshot = nil
        originalScreenshot = nil
        strokes = []
        issues = [:]
        notice = nil
        ticket = nil
        phase = .editing
    }

    private func remember(email: String?, name: String?) {
        // Only what the person typed: an identified user is the app's business.
        guard Faro.currentUser == nil else { return }
        let defaults = UserDefaults.standard
        if let email, !email.isEmpty { defaults.set(email, forKey: Self.emailKey) }
        if let name, !name.isEmpty {
            defaults.set(name, forKey: Self.nameKey)
        } else {
            defaults.removeObject(forKey: Self.nameKey)
        }
    }

    private func apply(_ error: FaroError) {
        switch error {
        case .network:
            notice = .offline
        case .rateLimited:
            notice = .rateLimited
        case .invalidForm(let field):
            let key = field.isEmpty ? FaroFormField.messageKey : field
            let empty = value(key).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            issues = [key: key == FaroForm.kindKey || empty ? .required : .invalid]
            if shownForm.field(key) == nil && key != FaroForm.kindKey { notice = .failed }
        case .invalidEmail:
            issues = [FaroFormField.emailKey: .invalidEmail]
        case .invalidMessage:
            issues = [FaroFormField.messageKey: .invalid]
        case .fileTooLarge, .fileTypeNotAllowed, .invalidAttachment:
            notice = .attachment
        case .moduleRequired, .widgetNotFound, .subscriptionInactive, .notConfigured:
            notice = .unavailable
        default:
            notice = .failed
        }
        issueRound += 1
    }
}
#endif
