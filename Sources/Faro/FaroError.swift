import Foundation

/**
 Everything that can go wrong talking to Faro, told apart by Faro's
 `errorCode` (never by the text of its message).

 ```swift
 do {
     let ticket = try await Faro.shared.send(request)
 } catch FaroError.invalidForm(let field) {
     highlight(field)            // "kind", "name" or one of your own keys
 } catch FaroError.invalidEmail {
     highlight("email")
 } catch let error as FaroError where error.isNetwork {
     showOfflineBanner()
 }
 ```
 */
public enum FaroError: Error, Sendable, Hashable {
    /// ``Faro/configure(key:app:locale:apiURL:)`` was not called, or the key is empty.
    case notConfigured
    /// Faro could not be reached (offline, DNS, timeout). Safe to retry.
    case network(String)
    /**
     A field is missing or invalid (`INVALID_FORM`). `field` is its key:
     `"kind"` (a kind the form does not offer), `"name"` (a required name) or
     one of the organization's own fields.
     */
    case invalidForm(field: String)
    /// The email is missing or not valid (`INVALID_EMAIL_FORMAT`).
    case invalidEmail
    /// The message is under 3 or over 4000 characters (`INVALID_TEXT`).
    case invalidMessage
    /// Too many requests in a short time, from this address or this network (`RATE_LIMITED`, 429).
    case rateLimited
    /**
     The anti-spam proof was rejected even after a retry with a fresh one
     (`SPAM_CHECK_FAILED`). `reason` is Faro's: `expired`, `too_fast`, `reused`…
     */
    case spamCheck(reason: String)
    /// An image is over 3 MB or there are more than 3 (`FILE_TOO_LARGE`).
    case fileTooLarge
    /// An attachment is not PNG, JPEG, GIF or WebP (`FILE_TYPE_NOT_ALLOWED`).
    case fileTypeNotAllowed
    /// An image could not be read or reduced to fit, or there are more than ``FaroAttachment/maxCount``.
    case invalidAttachment
    /// The organization does not have the Requests module (`MODULE_REQUIRED`).
    case moduleRequired
    /// The widget key does not exist, or its organization is not active (`WIDGET_NOT_FOUND`).
    case widgetNotFound
    /// The organization's subscription is not active (`SUBSCRIPTION_INACTIVE`).
    case subscriptionInactive
    /// Faro answered with something the SDK could not read.
    case invalidResponse
    /// Any other answer from Faro: its HTTP status, `errorCode` and message.
    case server(status: Int, code: String, message: String)

    /// Faro's `errorCode` for this error (`"INVALID_FORM"`), or the SDK's own for local ones (`"NETWORK"`).
    public var code: String {
        switch self {
        case .notConfigured: return "NOT_CONFIGURED"
        case .network: return "NETWORK"
        case .invalidForm: return "INVALID_FORM"
        case .invalidEmail: return "INVALID_EMAIL_FORMAT"
        case .invalidMessage: return "INVALID_TEXT"
        case .rateLimited: return "RATE_LIMITED"
        case .spamCheck: return "SPAM_CHECK_FAILED"
        case .fileTooLarge: return "FILE_TOO_LARGE"
        case .fileTypeNotAllowed: return "FILE_TYPE_NOT_ALLOWED"
        case .invalidAttachment: return "INVALID_ATTACHMENT"
        case .moduleRequired: return "MODULE_REQUIRED"
        case .widgetNotFound: return "WIDGET_NOT_FOUND"
        case .subscriptionInactive: return "SUBSCRIPTION_INACTIVE"
        case .invalidResponse: return "INVALID_RESPONSE"
        case .server(_, let code, _): return code
        }
    }

    /// The HTTP status Faro answered with, when the error came from Faro.
    public var status: Int? {
        switch self {
        case .notConfigured, .network, .invalidAttachment, .invalidResponse: return nil
        case .invalidForm, .invalidEmail, .invalidMessage, .spamCheck: return 400
        case .rateLimited: return 429
        case .fileTooLarge: return 413
        case .fileTypeNotAllowed: return 415
        case .moduleRequired, .subscriptionInactive: return 403
        case .widgetNotFound: return 404
        case .server(let status, _, _): return status
        }
    }

    /// Whether Faro could not be reached at all.
    public var isNetwork: Bool {
        if case .network = self { return true }
        return false
    }

    /// Whether the person can fix it by changing what they typed.
    public var isValidation: Bool {
        switch self {
        case .invalidForm, .invalidEmail, .invalidMessage: return true
        default: return false
        }
    }

    /**
     Maps an error answer from Faro: `{ "errorCode": "…", "errorNumber": 400028, "message": "…" }`.
     */
    static func from(status: Int, code: String?, message: String?) -> FaroError {
        let message = message ?? ""
        switch code {
        case "INVALID_FORM":
            // "field: where" → "where".
            if let range = message.range(of: "field:") {
                let field = message[range.upperBound...].trimmingCharacters(in: .whitespaces)
                if !field.isEmpty { return .invalidForm(field: field) }
            }
            return .invalidForm(field: "")
        case "INVALID_EMAIL_FORMAT": return .invalidEmail
        case "INVALID_TEXT": return .invalidMessage
        case "RATE_LIMITED": return .rateLimited
        case "SPAM_CHECK_FAILED":
            // "proof: expired" → "expired".
            let reason = message.range(of: "proof:").map {
                message[$0.upperBound...].trimmingCharacters(in: .whitespaces)
            } ?? message
            return .spamCheck(reason: reason)
        case "FILE_TOO_LARGE": return .fileTooLarge
        case "FILE_TYPE_NOT_ALLOWED": return .fileTypeNotAllowed
        case "MODULE_REQUIRED": return .moduleRequired
        case "WIDGET_NOT_FOUND": return .widgetNotFound
        case "SUBSCRIPTION_INACTIVE": return .subscriptionInactive
        default:
            if status == 429 { return .rateLimited }
            return .server(status: status, code: code ?? "HTTP_\(status)", message: message)
        }
    }

    /**
     Whether the proof survived the failure: Faro checks the text, the email,
     the form and the rate limit before the proof, and spends the proof only
     when the request gets in. A network failure may or may not have reached
     Faro; if the proof turns out spent, the automatic retry gets a new one.
     */
    var leavesProofUnspent: Bool {
        switch self {
        case .network, .invalidForm, .invalidEmail, .invalidMessage, .rateLimited:
            return true
        case .server(_, let code, _):
            return code == "INVALID_BODY" || code == "MISSING_PARAMETERS"
        default:
            return false
        }
    }
}

extension FaroError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notConfigured: return "Faro is not configured: call Faro.configure(key:app:) first."
        case .network(let detail): return "Couldn't reach Faro (\(detail))."
        case .invalidForm(let field): return "The field “\(field)” is missing or not valid."
        case .invalidEmail: return "The email address is missing or not valid."
        case .invalidMessage: return "The message must be between 3 and 4000 characters."
        case .rateLimited: return "Too many requests in a short time. Try again later."
        case .spamCheck(let reason): return "The anti-spam check failed (\(reason)). Try again."
        case .fileTooLarge: return "An image is over 3 MB, or there are more than 3."
        case .fileTypeNotAllowed: return "Only PNG, JPEG, GIF and WebP images can be attached."
        case .invalidAttachment: return "An image couldn't be read or reduced to 3 MB, or there are more than 3."
        case .moduleRequired: return "This organization doesn't take requests (the Requests module is off)."
        case .widgetNotFound: return "The Faro key doesn't exist or its organization isn't active."
        case .subscriptionInactive: return "The organization's Faro subscription isn't active."
        case .invalidResponse: return "Faro sent an answer the SDK couldn't read."
        case .server(let status, let code, let message):
            return message.isEmpty ? "Faro answered \(status) \(code)." : "Faro answered \(status) \(code): \(message)"
        }
    }
}
