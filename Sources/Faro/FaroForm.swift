import Foundation

/**
 A request kind. Faro knows three: ``problem``, ``suggestion`` and ``question``;
 each form offers some of them (``FaroForm/kinds``).

 Faro sends only the keys, never their names: what each kind is called on
 screen is up to the app (FaroUI names them in English, Spanish and Portuguese).
 */
public struct FaroKind: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral,
    CustomStringConvertible {
    /// The key Faro uses (`"problem"`).
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    /// Something is not working.
    public static let problem = FaroKind(rawValue: "problem")
    /// An idea or an improvement.
    public static let suggestion = FaroKind(rawValue: "suggestion")
    /// A question about the app.
    public static let question = FaroKind(rawValue: "question")

    /// The kinds Faro accepts, in its usual order.
    public static let all: [FaroKind] = [.problem, .suggestion, .question]

    public var description: String { rawValue }
}

/// How a field is entered. Unknown types from a newer Faro are read as ``text``.
public enum FaroFieldType: String, Sendable, Hashable, CaseIterable {
    /// One line of text.
    case text
    /// Several lines of text. The built-in `message` field is one.
    case textarea
    /// One option of a list (``FaroFormField/options``).
    case select
    /// A yes/no box. Its value is `"true"` when checked.
    case checkbox
    /// A number. A comma is accepted as the decimal separator.
    case number
    /// A phone number: digits, spaces and `+ ( ) - .`, 5 to 30 characters.
    case tel
    /// A web address starting with `http://` or `https://`.
    case url
    /// A date as `yyyy-MM-dd`.
    case date
    /// An email address. Only the built-in `email` field has this type.
    case email
}

/// Why a value is rejected, as found by ``FaroForm/validate(kind:values:)``.
public enum FaroFieldIssue: String, Sendable, Hashable {
    /// The field is required and empty (or the box unchecked, or no kind chosen).
    case required
    /// The email address is not valid.
    case invalidEmail
    /// The message is shorter than ``FaroForm/minimumMessageLength``.
    case tooShort
    /// The message is longer than ``FaroForm/maximumMessageLength``.
    case tooLong
    /// The value does not fit the field's type, or is not one of its options.
    case invalid
}

/// An option of a ``FaroFieldType/select`` field.
public struct FaroFieldOption: Sendable, Hashable, Identifiable {
    /// What is sent.
    public let value: String
    /// What is shown, in the form's language.
    public let label: String
    /// The key of the ``FaroOptionGroup`` it belongs to, if the list is grouped.
    public let group: String?

    public var id: String { value }

    public init(value: String, label: String, group: String? = nil) {
        self.value = value
        self.label = label
        self.group = group
    }
}

/// A heading that groups options of a list.
public struct FaroOptionGroup: Sendable, Hashable, Identifiable {
    public let key: String
    public let label: String

    public var id: String { key }

    public init(key: String, label: String) {
        self.key = key
        self.label = label
    }
}

/**
 One field of the form, with its texts already in the form's language.

 The three built-in fields have the keys ``nameKey``, ``emailKey`` and
 ``messageKey``; the rest are the organization's own, by the key set in the panel.
 */
public struct FaroFormField: Sendable, Hashable, Identifiable {
    /// The key of the built-in name field.
    public static let nameKey = "name"
    /// The key of the built-in email field.
    public static let emailKey = "email"
    /// The key of the built-in message field.
    public static let messageKey = "message"

    /// How wide the panel asked the field to be. Phones usually ignore it.
    public enum Width: String, Sendable, Hashable {
        case full, half
    }

    /// The key the value is sent under.
    public let key: String
    public let type: FaroFieldType
    /// The label. Empty when the panel left it empty: use your own then.
    public let label: String
    /// The hint shown inside the empty field.
    public let placeholder: String
    /// A short explanation under the field.
    public let help: String
    public let isRequired: Bool
    public let width: Width
    /// The options of a ``FaroFieldType/select`` field, in order.
    public let options: [FaroFieldOption]
    /// The option groups of a ``FaroFieldType/select`` field, if any.
    public let groups: [FaroOptionGroup]

    public var id: String { key }

    /// Whether it is one of the three built-in fields (name, email, message).
    public var isBuiltIn: Bool {
        key == Self.nameKey || key == Self.emailKey || key == Self.messageKey
    }

    public init(
        key: String,
        type: FaroFieldType,
        label: String = "",
        placeholder: String = "",
        help: String = "",
        isRequired: Bool = false,
        width: Width = .full,
        options: [FaroFieldOption] = [],
        groups: [FaroOptionGroup] = []
    ) {
        self.key = key
        self.type = type
        self.label = label
        self.placeholder = placeholder
        self.help = help
        self.isRequired = isRequired
        self.width = width
        self.options = options
        self.groups = groups
    }
}

/**
 The request form, as defined in the Faro panel and resolved to one language.

 Draw your screen from it: ``kinds`` first, then ``fields`` in order. Every
 value is a string by field key (a checked box is `"true"`), which is what
 ``validate(kind:values:)`` and ``request(kind:values:attachments:)`` take.
 */
public struct FaroForm: Sendable, Hashable {
    /// Where the form came from.
    public enum Source: String, Sendable, Hashable {
        /// Fetched from Faro just now.
        case network
        /// The last one fetched, read from the disk cache.
        case cache
        /// Built in: Faro could not be reached and nothing was cached.
        case fallback
    }

    /// The key ``validate(kind:values:)`` reports a missing kind under.
    public static let kindKey = "kind"
    /// Faro's minimum message length, in Unicode scalars.
    public static let minimumMessageLength = 3
    /// Faro's maximum message length, in Unicode scalars.
    public static let maximumMessageLength = 4000

    /// The language the texts are in: the one asked for if the form offers it, else its primary one.
    public let locale: String
    /// Every language the form has texts in; the first is the primary.
    public let locales: [String]
    /// The heading. Empty when the panel left it empty.
    public let title: String
    /// A sentence under the heading.
    public let intro: String
    /// The text of the send button.
    public let submitLabel: String
    /// The message shown once the request is in.
    public let successMessage: String
    /// The request kinds on offer, in order.
    public let kinds: [FaroKind]
    /// Every field to ask, in order. The name is left out when the panel turned it off.
    public let fields: [FaroFormField]
    /// The organization's name.
    public let organizationName: String
    /// The organization's brand color as `#rrggbb`, if set.
    public let brandColor: String?
    /// `false` when the organization does not have the Requests module: sending will fail.
    public let acceptsRequests: Bool
    public let source: Source

    public init(
        locale: String,
        locales: [String] = [],
        title: String = "",
        intro: String = "",
        submitLabel: String = "",
        successMessage: String = "",
        kinds: [FaroKind] = FaroKind.all,
        fields: [FaroFormField],
        organizationName: String = "",
        brandColor: String? = nil,
        acceptsRequests: Bool = true,
        source: Source = .network
    ) {
        self.locale = locale
        self.locales = locales.isEmpty ? [locale] : locales
        self.title = title
        self.intro = intro
        self.submitLabel = submitLabel
        self.successMessage = successMessage
        self.kinds = kinds.isEmpty ? FaroKind.all : kinds
        self.fields = fields
        self.organizationName = organizationName
        self.brandColor = brandColor
        self.acceptsRequests = acceptsRequests
        self.source = source
    }

    /**
     A minimal form to fall back on when Faro cannot be reached and nothing is
     cached: the three kinds, an optional name, the email and the message,
     without texts (use your own labels).
     */
    public static func fallback(locale: String? = nil) -> FaroForm {
        FaroForm(
            locale: FaroLocale.language(locale),
            fields: [
                FaroFormField(key: FaroFormField.messageKey, type: .textarea, isRequired: true),
                FaroFormField(key: FaroFormField.emailKey, type: .email, isRequired: true),
                FaroFormField(key: FaroFormField.nameKey, type: .text),
            ],
            source: .fallback
        )
    }

    /// The field with that key, if the form asks for it.
    public func field(_ key: String) -> FaroFormField? {
        fields.first { $0.key == key }
    }

    // MARK: Validation

    /**
     Runs the same checks Faro runs, so mistakes show up before a round trip.

     - Parameters:
       - kind: The chosen kind, or `nil` if none was chosen yet.
       - values: Every value by field key. A checked box is `"true"`.
     - Returns: The issues by field key (``kindKey`` for the kind). Empty when all is well.
     */
    public func validate(kind: FaroKind?, values: [String: String]) -> [String: FaroFieldIssue] {
        var issues: [String: FaroFieldIssue] = [:]
        if kind.map({ !kinds.contains($0) }) ?? true { issues[Self.kindKey] = .required }
        for field in fields {
            let value = (values[field.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let issue = Validation.issue(for: field, value: value) { issues[field.key] = issue }
        }
        return issues
    }

    /**
     Builds the request from what was typed: `message`, `email` and `name` go
     to their own properties, the rest to ``FaroRequest/fields`` (unchecked
     boxes and empty values are left out). Values are trimmed.
     */
    public func request(
        kind: FaroKind,
        values: [String: String],
        attachments: [FaroAttachment] = []
    ) -> FaroRequest {
        func value(_ key: String) -> String {
            (values[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var custom: [String: String] = [:]
        for field in fields where !field.isBuiltIn {
            let v = value(field.key)
            guard !v.isEmpty else { continue }
            if field.type == .checkbox && v != "true" { continue }
            custom[field.key] = v
        }
        let name = value(FaroFormField.nameKey)
        let email = value(FaroFormField.emailKey)
        var request = FaroRequest(
            kind: kind,
            message: value(FaroFormField.messageKey),
            email: email.isEmpty ? nil : email,
            name: field(FaroFormField.nameKey) == nil || name.isEmpty ? nil : name,
            fields: custom,
            attachments: attachments
        )
        request.locale = locale
        return request
    }
}

// MARK: - Validation rules

enum Validation {
    private static let email = try! NSRegularExpression(
        pattern: "^[A-Z0-9a-z._%+\\-']+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$"
    )
    private static let phone = try! NSRegularExpression(pattern: "^[0-9+()\\-.\\s]{5,30}$")

    private static func matches(_ expression: NSRegularExpression, _ text: String) -> Bool {
        expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    static func isEmail(_ text: String) -> Bool {
        text.count <= 254 && matches(email, text)
    }

    static func isDate(_ text: String) -> Bool {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return text.count == 10 && formatter.date(from: text) != nil
    }

    /// The issue with `value` (already trimmed) for `field`, or `nil`.
    static func issue(for field: FaroFormField, value: String) -> FaroFieldIssue? {
        switch field.key {
        case FaroFormField.emailKey:
            if value.isEmpty { return .required }
            return isEmail(value) ? nil : .invalidEmail
        case FaroFormField.messageKey:
            let length = value.unicodeScalars.count
            if value.isEmpty { return .required }
            if length < FaroForm.minimumMessageLength { return .tooShort }
            if length > FaroForm.maximumMessageLength { return .tooLong }
            return nil
        default:
            break
        }
        if field.type == .checkbox {
            return field.isRequired && value != "true" ? .required : nil
        }
        if value.isEmpty { return field.isRequired ? .required : nil }
        let valid: Bool
        switch field.type {
        case .select:
            valid = field.options.contains { $0.value == value }
        case .number:
            valid = Double(value.replacingOccurrences(of: ",", with: ".")) != nil
        case .tel:
            valid = matches(phone, value)
        case .url:
            let url = URL(string: value)
            valid = (url?.scheme == "http" || url?.scheme == "https") && !(url?.host ?? "").isEmpty
        case .date:
            valid = isDate(value)
        case .email:
            valid = isEmail(value)
        case .text, .textarea, .checkbox:
            valid = true
        }
        return valid ? nil : .invalid
    }
}
