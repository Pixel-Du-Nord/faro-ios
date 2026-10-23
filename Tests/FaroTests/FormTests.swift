import XCTest
@testable import Faro

final class FormTests: XCTestCase {
    /// A `/widget/config` answer like Parqués', plus the older shapes Faro still accepts.
    static var config: [String: Any] { [
        "success": true,
        "widget": [
            "orgName": "Pixel du Nord",
            "modules": ["errors": true, "requests": true],
            "settings": [
                "color": "#EAA834",
                "requestForm": [
                    "locales": ["es", "en"],
                    "title": ["en": "Write to us", "es": "Escríbenos"],
                    "intro": "Texto plano de antes",
                    "submit": ["es": "Enviar"],
                    "kinds": ["question", "problem", "bogus", "question"],
                    "name": "required",
                    "email": ["label": ["en": "Your email", "es": "Tu correo"], "width": "half"],
                    "message": ["placeholder": ["es": "¿Qué pasó?", "en": "What happened?"]],
                    "fields": [
                        [
                            "key": "where", "type": "select", "required": true,
                            "label": ["en": "Where?", "es": "¿Dónde?"],
                            "options": [
                                ["value": "online", "label": ["en": "Online", "es": "En línea"], "group": "play"],
                                "Tienda",
                                ["label": ["es": "Otra"]],
                            ],
                            "groups": [["key": "play", "label": ["es": "Jugar"]]],
                        ],
                        ["key": "phone", "type": "tel", "label": ["es": "Teléfono"]],
                        ["key": "future", "type": "hologram", "label": ["es": "Algo nuevo"]],
                        ["key": "name", "type": "text", "label": ["es": "Duplicado de un fijo"]],
                    ],
                    "order": ["message", "where", "ghost", "email", "where"],
                ],
            ],
        ],
    ] }

    private func form(_ language: String) -> FaroForm {
        FormSnapshot(configResponse: Self.config)!.form(language: language, source: .network)
    }

    func testResolvesTextsToTheAskedLanguage() {
        let en = form("en")
        XCTAssertEqual(en.locale, "en")
        XCTAssertEqual(en.title, "Write to us")
        // Missing in English: falls back to the primary (Spanish), then the plain text.
        XCTAssertEqual(en.submitLabel, "Enviar")
        XCTAssertEqual(en.intro, "Texto plano de antes")
        XCTAssertEqual(en.field("email")?.label, "Your email")
        XCTAssertEqual(en.field("message")?.placeholder, "What happened?")
    }

    func testUnknownLanguageUsesThePrimary() {
        let pt = form("pt")
        XCTAssertEqual(pt.locale, "es")
        XCTAssertEqual(pt.title, "Escríbenos")
        XCTAssertEqual(pt.locales, ["es", "en"])
    }

    func testOrderKindsAndFields() {
        let f = form("es")
        // Faro's order without unknown or repeated keys, then the missing custom fields, then the built-ins.
        XCTAssertEqual(f.fields.map(\.key), ["message", "where", "email", "phone", "future", "name"])
        XCTAssertEqual(f.kinds, [.question, .problem])
        XCTAssertEqual(f.field("name")?.isRequired, true)
        XCTAssertEqual(f.field("name")?.label, "")
        XCTAssertEqual(f.field("future")?.type, .text)
        XCTAssertEqual(f.field("email")?.type, .email)
        XCTAssertEqual(f.field("email")?.width, .half)
        XCTAssertEqual(f.field("message")?.type, .textarea)
        XCTAssertEqual(f.organizationName, "Pixel du Nord")
        XCTAssertEqual(f.brandColor, "#eaa834")
        XCTAssertTrue(f.acceptsRequests)
    }

    func testOptionsInEveryShape() {
        let options = form("es").field("where")!.options
        XCTAssertEqual(options.map(\.value), ["online", "Tienda", "Otra"])
        XCTAssertEqual(options.map(\.label), ["En línea", "Tienda", "Otra"])
        XCTAssertEqual(options.first?.group, "play")
        XCTAssertEqual(form("es").field("where")?.groups, [FaroOptionGroup(key: "play", label: "Jugar")])
    }

    func testNameOffIsLeftOut() {
        let snapshot = FormSnapshot(
            requestForm: ["name": ["mode": "off"], "locales": ["en"]],
            organizationName: "", brandColor: nil, acceptsRequests: false
        )
        let f = snapshot.form(language: "en", source: .cache)
        XCTAssertNil(f.field("name"))
        XCTAssertEqual(f.fields.map(\.key), ["email", "message"])
        XCTAssertEqual(f.kinds, FaroKind.all)
        XCTAssertFalse(f.acceptsRequests)
        XCTAssertEqual(f.source, .cache)
    }

    func testCacheRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = FormCache(configuration: FaroConfiguration(key: "wk_test", app: "Parques"), directory: directory)
        XCTAssertNil(cache.load())
        cache.save(FormSnapshot(configResponse: Self.config)!)
        let loaded = try XCTUnwrap(cache.load()).form(language: "en", source: .cache)
        var expected = form("en")
        expected = FaroForm(
            locale: expected.locale, locales: expected.locales, title: expected.title, intro: expected.intro,
            submitLabel: expected.submitLabel, successMessage: expected.successMessage, kinds: expected.kinds,
            fields: expected.fields, organizationName: expected.organizationName, brandColor: expected.brandColor,
            acceptsRequests: expected.acceptsRequests, source: .cache
        )
        XCTAssertEqual(loaded, expected)
    }

    func testLanguageNormalization() {
        XCTAssertEqual(FaroLocale.language("pt-BR"), "pt")
        XCTAssertEqual(FaroLocale.language("es_CO"), "es")
        XCTAssertEqual(FaroLocale.language("EN"), "en")
        XCTAssertFalse(FaroLocale.language(nil).isEmpty)
    }

    // MARK: Validation

    func testValidation() {
        let f = form("es")
        var values = ["message": "Hi", "email": "not-an-email", "where": "nowhere", "phone": "12"]
        var issues = f.validate(kind: nil, values: values)
        XCTAssertEqual(issues["kind"], .required)
        XCTAssertEqual(issues["message"], .tooShort)
        XCTAssertEqual(issues["email"], .invalidEmail)
        XCTAssertEqual(issues["where"], .invalid)
        XCTAssertEqual(issues["phone"], .invalid)
        XCTAssertEqual(issues["name"], .required)

        values = ["message": "The board froze", "email": "ana@example.com", "where": "online", "name": "Ana"]
        issues = f.validate(kind: .problem, values: values)
        XCTAssertEqual(issues, [:])

        // A kind the form does not offer.
        XCTAssertEqual(f.validate(kind: .suggestion, values: values)["kind"], .required)
        // Too long.
        values["message"] = String(repeating: "a", count: 4001)
        XCTAssertEqual(f.validate(kind: .problem, values: values)["message"], .tooLong)
    }

    func testTypedValidation() {
        func issue(_ type: FaroFieldType, _ value: String, required: Bool = false) -> FaroFieldIssue? {
            Validation.issue(for: FaroFormField(key: "x", type: type, isRequired: required), value: value)
        }
        XCTAssertNil(issue(.number, "3,5"))
        XCTAssertEqual(issue(.number, "three"), .invalid)
        XCTAssertNil(issue(.url, "https://pixeldunord.com/a"))
        XCTAssertEqual(issue(.url, "pixeldunord.com"), .invalid)
        XCTAssertNil(issue(.date, "2026-10-22"))
        XCTAssertEqual(issue(.date, "2026-02-30"), .invalid)
        XCTAssertNil(issue(.tel, "+57 (318) 066-5776"))
        XCTAssertEqual(issue(.checkbox, "", required: true), .required)
        XCTAssertNil(issue(.checkbox, "true", required: true))
        XCTAssertNil(issue(.text, ""))
        XCTAssertEqual(issue(.text, "", required: true), .required)
    }

    func testRequestFromValues() {
        let f = FaroForm(
            locale: "es",
            fields: [
                FaroFormField(key: "message", type: .textarea, isRequired: true),
                FaroFormField(key: "email", type: .email, isRequired: true),
                FaroFormField(key: "name", type: .text),
                FaroFormField(key: "agree", type: .checkbox),
                FaroFormField(key: "promo", type: .checkbox),
                FaroFormField(key: "where", type: .text),
            ]
        )
        let request = f.request(
            kind: .question,
            values: ["message": "  ¿Cómo juego?  ", "email": "ana@example.com", "name": "", "agree": "true",
                     "promo": "", "where": " casa ", "stray": "ignored"]
        )
        XCTAssertEqual(request.kind, .question)
        XCTAssertEqual(request.message, "¿Cómo juego?")
        XCTAssertEqual(request.email, "ana@example.com")
        XCTAssertNil(request.name)
        XCTAssertEqual(request.fields, ["agree": "true", "where": "casa"])
        XCTAssertEqual(request.locale, "es")
    }
}
