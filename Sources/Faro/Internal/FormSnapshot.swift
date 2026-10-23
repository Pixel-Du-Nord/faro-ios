import Foundation

/**
 A text per language as Faro sends it: `{"en": "Your name", "es": "Tu nombre"}`.
 A plain string (Faro's older shape) counts as the primary language's text and
 is stored under the empty key.
 */
struct LocalizedText: Sendable, Hashable {
    let values: [String: String]

    init(_ raw: Any?) {
        if let text = raw as? String {
            values = ["": text]
        } else if let map = raw as? [String: Any] {
            values = map.compactMapValues { $0 as? String }
        } else {
            values = [:]
        }
    }

    /// The text in `language`; else in `primary`; else the plain one.
    func resolve(_ language: String, primary: String) -> String {
        for key in [language, primary, ""] {
            if let value = values[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }
        return ""
    }
}

/**
 What the SDK keeps of `GET /widget/config`: the raw `requestForm` plus the few
 organization facts the screen uses. It is also what goes to the disk cache,
 as JSON, so a cached form resolves exactly like a fresh one.
 */
struct FormSnapshot: @unchecked Sendable {
    // `[String: Any]` is a JSON tree of immutable Foundation values.
    let requestForm: [String: Any]
    let organizationName: String
    let brandColor: String?
    let acceptsRequests: Bool

    init(requestForm: [String: Any], organizationName: String, brandColor: String?, acceptsRequests: Bool) {
        self.requestForm = requestForm
        self.organizationName = organizationName
        self.brandColor = brandColor
        self.acceptsRequests = acceptsRequests
    }

    /// Reads the `/widget/config` response; `nil` if it has no `widget.settings`.
    init?(configResponse body: [String: Any]) {
        guard let widget = body["widget"] as? [String: Any],
              let settings = widget["settings"] as? [String: Any] else { return nil }
        let modules = widget["modules"] as? [String: Any]
        self.init(
            requestForm: settings["requestForm"] as? [String: Any] ?? [:],
            organizationName: widget["orgName"] as? String ?? "",
            brandColor: Self.hexColor(settings["color"]),
            acceptsRequests: modules?["requests"] as? Bool ?? true
        )
    }

    /// Reads what ``json`` wrote.
    init?(cached data: Data) {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let form = object["requestForm"] as? [String: Any] else { return nil }
        self.init(
            requestForm: form,
            organizationName: object["organizationName"] as? String ?? "",
            brandColor: Self.hexColor(object["brandColor"]),
            acceptsRequests: object["acceptsRequests"] as? Bool ?? true
        )
    }

    /// The snapshot as JSON, for the disk cache.
    var json: Data? {
        var object: [String: Any] = [
            "requestForm": requestForm,
            "organizationName": organizationName,
            "acceptsRequests": acceptsRequests,
        ]
        if let brandColor { object["brandColor"] = brandColor }
        return try? JSONSerialization.data(withJSONObject: object)
    }

    private static func hexColor(_ raw: Any?) -> String? {
        guard let text = (raw as? String)?.trimmingCharacters(in: .whitespaces).lowercased(),
              text.count == 7, text.hasPrefix("#"),
              text.dropFirst().allSatisfy(\.isHexDigit) else { return nil }
        return text
    }

    /**
     Resolves the definition to `language`. Lenient: anything missing or
     malformed takes its default, and the older shapes (plain-text labels,
     options as strings, `name` as a bare mode) are still read.
     */
    func form(language: String, source: FaroForm.Source) -> FaroForm {
        let json = requestForm
        let locales = (json["locales"] as? [Any] ?? []).compactMap { $0 as? String }.map { $0.lowercased() }
        let primary = locales.first ?? ""
        let locale = locales.contains(language) ? language : (locales.first ?? language)
        func text(_ raw: Any?) -> String { LocalizedText(raw).resolve(locale, primary: primary) }

        // The three built-ins. `name` used to be a bare mode string.
        func builtIn(_ raw: Any?) -> [String: Any] {
            if let mode = raw as? String { return ["mode": mode] }
            return raw as? [String: Any] ?? [:]
        }
        let name = builtIn(json["name"])
        let email = builtIn(json["email"])
        let message = builtIn(json["message"])
        let nameMode = name["mode"] as? String ?? "optional"

        func width(_ raw: Any?) -> FaroFormField.Width {
            (raw as? String) == "half" ? .half : .full
        }

        var byKey: [String: FaroFormField] = [:]
        var customKeys: [String] = []
        for case let raw as [String: Any] in json["fields"] as? [Any] ?? [] {
            guard let key = raw["key"] as? String, !key.isEmpty, byKey[key] == nil,
                  ![FaroFormField.nameKey, FaroFormField.emailKey, FaroFormField.messageKey].contains(key)
            else { continue }
            let type = FaroFieldType(rawValue: raw["type"] as? String ?? "") ?? .text
            let options: [FaroFieldOption] = (raw["options"] as? [Any] ?? []).compactMap { option in
                if let plain = option as? String { return FaroFieldOption(value: plain, label: plain) }
                guard let object = option as? [String: Any] else { return nil }
                let label = text(object["label"])
                let value = (object["value"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? label
                guard !value.isEmpty else { return nil }
                let group = (object["group"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                return FaroFieldOption(value: value, label: label.isEmpty ? value : label, group: group)
            }
            let groups: [FaroOptionGroup] = (raw["groups"] as? [Any] ?? []).compactMap { group in
                guard let object = group as? [String: Any], let key = object["key"] as? String else { return nil }
                return FaroOptionGroup(key: key, label: text(object["label"]))
            }
            byKey[key] = FaroFormField(
                key: key,
                type: type == .email ? .text : type,
                label: text(raw["label"]),
                placeholder: text(raw["placeholder"]),
                help: text(raw["help"]),
                isRequired: raw["required"] as? Bool ?? false,
                width: type == .textarea ? .full : width(raw["width"]),
                options: type == .select ? options : [],
                groups: type == .select ? groups : []
            )
            customKeys.append(key)
        }
        if nameMode != "off" {
            byKey[FaroFormField.nameKey] = FaroFormField(
                key: FaroFormField.nameKey, type: .text,
                label: text(name["label"]), placeholder: text(name["placeholder"]), help: text(name["help"]),
                isRequired: nameMode == "required", width: width(name["width"])
            )
        }
        byKey[FaroFormField.emailKey] = FaroFormField(
            key: FaroFormField.emailKey, type: .email,
            label: text(email["label"]), placeholder: text(email["placeholder"]), help: text(email["help"]),
            isRequired: true, width: width(email["width"])
        )
        byKey[FaroFormField.messageKey] = FaroFormField(
            key: FaroFormField.messageKey, type: .textarea,
            label: text(message["label"]), placeholder: text(message["placeholder"]), help: text(message["help"]),
            isRequired: true
        )

        // Faro's order without unknown or repeated keys; whatever is missing goes
        // last (custom fields before the built-ins, as Faro itself does).
        var order: [String] = []
        for case let key as String in json["order"] as? [Any] ?? [] where byKey[key] != nil && !order.contains(key) {
            order.append(key)
        }
        for key in customKeys + [FaroFormField.nameKey, FaroFormField.emailKey, FaroFormField.messageKey]
            where byKey[key] != nil && !order.contains(key) {
            order.append(key)
        }

        var kinds: [FaroKind] = []
        for case let raw as String in json["kinds"] as? [Any] ?? [] {
            let kind = FaroKind(rawValue: raw)
            if FaroKind.all.contains(kind) && !kinds.contains(kind) { kinds.append(kind) }
        }

        return FaroForm(
            locale: locale,
            locales: locales.isEmpty ? [locale] : locales,
            title: text(json["title"]),
            intro: text(json["intro"]),
            submitLabel: text(json["submit"]),
            successMessage: text(json["success"]),
            kinds: kinds,
            fields: order.compactMap { byKey[$0] },
            organizationName: organizationName,
            brandColor: brandColor,
            acceptsRequests: acceptsRequests,
            source: source
        )
    }
}

/// The last form definition, on disk (in Caches: the system may purge it, which is fine).
struct FormCache: Sendable {
    let file: URL?

    init(configuration: FaroConfiguration, directory: URL?) {
        let base = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("FaroSDK", isDirectory: true)
        let name = "\(configuration.key)-\(configuration.app ?? "_")"
            .map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" ? String($0) : "_" }
            .joined()
        file = base?.appendingPathComponent("form-\(name).json")
    }

    func load() -> FormSnapshot? {
        guard let file, let data = try? Data(contentsOf: file) else { return nil }
        return FormSnapshot(cached: data)
    }

    func save(_ snapshot: FormSnapshot) {
        guard let file, let data = snapshot.json else { return }
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: file, options: .atomic)
    }
}
