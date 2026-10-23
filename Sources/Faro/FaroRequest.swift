import Foundation

/**
 What is sent to Faro. Build it yourself or with ``FaroForm/request(kind:values:attachments:)``.

 The device facts, the identified user and the breadcrumbs are added by
 ``Faro/send(_:)``; you do not need to set them.
 */
public struct FaroRequest: Sendable, Hashable {
    /// One of the kinds the form offers (``FaroForm/kinds``).
    public var kind: FaroKind
    /// What the person wrote: 3 to 4000 characters. Its first line becomes the subject.
    public var message: String
    /// Where the reply goes. `nil` uses the email of the identified user (``Faro/identify(_:)``).
    public var email: String?
    /**
     The person's name. `nil` uses the identified user's; `""` sends no name at
     all, even for an identified person (what ``FaroForm/request(kind:values:attachments:)``
     does when the form has the name turned off).
     */
    public var name: String?
    /// A subject (up to 120 characters) instead of the message's first line.
    public var subject: String?
    /// The organization's own fields, by key. A checked box is `"true"`.
    public var fields: [String: String]
    /// Up to ``FaroAttachment/maxCount`` images.
    public var attachments: [FaroAttachment]
    /**
     The language of the emails the person will get, cut to its base (`"pt-BR"`
     → `"pt"`). `nil` uses the configured one, then the device's.
     */
    public var locale: String?
    /**
     Extra device facts of your own (`["plan": "pro"]`). They join the automatic
     ones (``Faro/deviceFacts(adding:includesBreadcrumbs:)``) up to Faro's limit of 12. Never put
     keys, tokens, account names or personal data here.
     */
    public var device: [String: String]
    /// Whether the breadcrumbs (``Faro/breadcrumb(_:)``) travel with this request. `true` by default.
    public var includesBreadcrumbs: Bool

    public init(
        kind: FaroKind,
        message: String,
        email: String? = nil,
        name: String? = nil,
        subject: String? = nil,
        fields: [String: String] = [:],
        attachments: [FaroAttachment] = [],
        locale: String? = nil,
        device: [String: String] = [:],
        includesBreadcrumbs: Bool = true
    ) {
        self.kind = kind
        self.message = message
        self.email = email
        self.name = name
        self.subject = subject
        self.fields = fields
        self.attachments = attachments
        self.locale = locale
        self.device = device
        self.includesBreadcrumbs = includesBreadcrumbs
    }
}

/// A request that made it in.
public struct FaroTicket: Sendable, Hashable, Codable {
    /// The request number the team sees (`#123`). Mention it when writing again.
    public let number: Int
    /// The address replies will go to.
    public let email: String
    /**
     Whether that address is confirmed. It is when the person was identified
     with a valid signature; otherwise Faro asks them to confirm it with the
     first reply, so the form cannot be used to send mail to strangers.
     */
    public let isConfirmed: Bool

    public init(number: Int, email: String, isConfirmed: Bool) {
        self.number = number
        self.email = email
        self.isConfirmed = isConfirmed
    }

    init?(response body: [String: Any]) {
        guard let ticket = body["ticket"] as? [String: Any],
              let number = (ticket["number"] as? NSNumber)?.intValue else { return nil }
        self.init(
            number: number,
            email: ticket["email"] as? String ?? "",
            isConfirmed: ticket["confirmed"] as? Bool ?? false
        )
    }
}

/**
 The person using the app, for ``Faro/identify(_:)``.

 Without a signature, the email and name only prefill the form. With one, the
 request is linked to the person's contact in Faro and their email counts as
 confirmed. The signature is the HMAC-SHA256 of `id` with your widget's identity
 secret, in hex, computed by **your server** (see the Identity guide in the
 Faro docs). Never ship the secret in the app.
 */
public struct FaroUser: Sendable, Hashable {
    /**
     Your own, stable id for the person, optional. Unsigned, it travels as the
     `userId` device fact so your team can look the person up.
     */
    public var id: String?
    public var email: String?
    public var name: String?
    /// HMAC-SHA256 of `id` with the identity secret, from your server.
    public var signature: String?

    public init(id: String? = nil, email: String? = nil, name: String? = nil, signature: String? = nil) {
        self.id = id
        self.email = email
        self.name = name
        self.signature = signature
    }

    /// Whether Faro can verify this person: both ``id`` and ``signature`` are set.
    public var isSigned: Bool {
        !(id ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !(signature ?? "").isEmpty
    }
}

/// Something the person did, recorded with ``Faro/breadcrumb(_:)``.
public struct FaroBreadcrumb: Sendable, Hashable {
    /// How many are kept: the oldest ones are dropped.
    public static let limit = 20
    /// Longer messages are cut to this many characters.
    public static let maxLength = 60

    public let date: Date
    public let message: String

    public init(date: Date = Date(), message: String) {
        self.date = date
        self.message = message
    }
}

/// The breadcrumbs, in memory and thread-safe.
final class BreadcrumbTrail: Sendable {
    private let entries = Locked<[FaroBreadcrumb]>([])

    func add(_ message: String) {
        let clean = message
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !clean.isEmpty else { return }
        let entry = FaroBreadcrumb(message: String(clean.prefix(FaroBreadcrumb.maxLength)))
        entries.withLock { list in
            list.append(entry)
            if list.count > FaroBreadcrumb.limit { list.removeFirst(list.count - FaroBreadcrumb.limit) }
        }
    }

    var all: [FaroBreadcrumb] { entries.withLock { $0 } }

    func clear() { entries.withLock { $0.removeAll() } }

    /**
     The newest breadcrumbs that fit in `max` characters, oldest first, joined
     with ` › `. Faro keeps device values up to 120 characters, so this is the
     trail the team sees in the panel today.
     */
    static func trail(_ crumbs: [FaroBreadcrumb], max: Int = 120) -> String {
        var picked: [String] = []
        var length = 0
        for crumb in crumbs.reversed() {
            let extra = crumb.message.count + (picked.isEmpty ? 0 : separator.count)
            if length + extra > max {
                if picked.isEmpty { picked.append(String(crumb.message.prefix(max))) }
                break
            }
            picked.insert(crumb.message, at: 0)
            length += extra
        }
        return picked.joined(separator: separator)
    }

    private static let separator = " › "
}
