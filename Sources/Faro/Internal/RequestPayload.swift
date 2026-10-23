import Foundation

/**
 The body of `POST /widget/requests`, minus the proof (which changes between
 attempts). JSON, or multipart with `data` (the same JSON) and one `file` part
 per image.
 */
struct RequestPayload: @unchecked Sendable {
    // `fields` is an immutable JSON tree of Foundation values.
    let fields: [String: Any]
    let attachments: [FaroAttachment]

    init(
        request: FaroRequest,
        configuration: FaroConfiguration,
        user: FaroUser?,
        breadcrumbs: [FaroBreadcrumb],
        device: [String: String]
    ) {
        func clean(_ text: String?) -> String {
            (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let email = clean(request.email).isEmpty ? clean(user?.email) : clean(request.email)
        let name = clean(request.name).isEmpty ? clean(user?.name) : clean(request.name)
        var fields: [String: Any] = [
            "key": configuration.key,
            "platform": "ios",
            "kind": request.kind.rawValue,
            "message": request.message.trimmingCharacters(in: .whitespacesAndNewlines),
            "email": email,
            "name": name,
            "locale": FaroLocale.language(request.locale ?? configuration.locale),
            "fields": request.fields.filter { !$0.value.isEmpty },
            "device": device,
            // The honeypot: invisible to people, always empty.
            "website": "",
        ]
        if let app = configuration.app { fields["app"] = app }
        let subject = clean(request.subject)
        if !subject.isEmpty { fields["subject"] = String(subject.prefix(120)) }
        if let user, let signature = user.signature, !signature.isEmpty, !clean(user.id).isEmpty {
            var signed: [String: Any] = ["id": clean(user.id), "signature": signature]
            if let email = user.email { signed["email"] = email }
            if let name = user.name { signed["name"] = name }
            fields["user"] = signed
        }
        if !breadcrumbs.isEmpty {
            // Same shape as the Android SDK: the text and how many seconds ago it happened.
            let now = Date()
            fields["context"] = [
                "breadcrumbs": breadcrumbs.map { crumb -> [String: Any] in
                    ["text": crumb.message, "ago": max(0, Int(now.timeIntervalSince(crumb.date)))]
                },
            ]
        }
        self.fields = fields
        self.attachments = request.attachments
    }

    /// The JSON with the proof added.
    func json(proof: FaroProof) throws -> Data {
        var body = fields
        body["proof"] = proof.payload
        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    func urlRequest(to url: URL, proof: FaroProof) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let json = try json(proof: proof)
        if attachments.isEmpty {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = json
        } else {
            let multipart = MultipartBody(json: json, attachments: attachments)
            request.setValue(multipart.contentType, forHTTPHeaderField: "Content-Type")
            request.httpBody = multipart.data
        }
        return request
    }
}

/// A `multipart/form-data` body: the JSON as `data`, then each image as `file`.
struct MultipartBody: Sendable {
    let boundary: String
    let data: Data

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    init(json: Data, attachments: [FaroAttachment], boundary: String = "faro-\(UUID().uuidString)") {
        self.boundary = boundary
        var body = Data()
        func part(name: String, content: Data, filename: String? = nil, type: String? = nil) {
            var header = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\""
            if let filename { header += "; filename=\"\(filename.replacingOccurrences(of: "\"", with: ""))\"" }
            header += "\r\n"
            if let type { header += "Content-Type: \(type)\r\n" }
            body.append(Data((header + "\r\n").utf8))
            body.append(content)
            body.append(Data("\r\n".utf8))
        }
        part(name: "data", content: json)
        for attachment in attachments.prefix(FaroAttachment.maxCount) {
            part(name: "file", content: attachment.data, filename: attachment.filename, type: attachment.mimeType)
        }
        body.append(Data("--\(boundary)--\r\n".utf8))
        self.data = body
    }
}
