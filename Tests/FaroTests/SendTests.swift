import CryptoKit
import XCTest
@testable import Faro

/// A fake Faro: answers each call from a script and records what it got.
final class FakeTransport: FaroTransport, @unchecked Sendable {
    struct Call {
        let request: URLRequest
        var path: String { request.url?.path ?? "" }
        var body: Data { request.httpBody ?? Data() }
    }

    private struct State {
        var calls: [Call] = []
        var submissions: [(Int, [String: Any])]
        var challengeCount = 0
    }

    private let state: Locked<State>

    /// Each POST takes the next scripted (status, body); challenges are generated.
    init(submissions: [(Int, [String: Any])]) {
        state = Locked(State(submissions: submissions))
    }

    var calls: [Call] { state.withLock { $0.calls } }
    var posts: [Call] { calls.filter { $0.path == "/widget/requests" } }
    var challenges: Int { calls.filter { $0.path == "/widget/challenge" }.count }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let path = request.url?.path ?? ""
        let (status, body): (Int, [String: Any]) = state.withLock { state in
            state.calls.append(Call(request: request))
            switch path {
            case "/widget/challenge":
                state.challengeCount += 1
                let count = state.challengeCount
                let salt = "salt\(count)?k=wk_test&t=1&"
                let digest = SHA256.hash(data: Data((salt + String(1_000 + count)).utf8))
                return (200, ["algorithm": "SHA-256", "salt": salt, "maxnumber": 50_000, "signature": "sig\(count)",
                              "challenge": digest.map { String(format: "%02x", $0) }.joined()])
            case "/widget/requests":
                return state.submissions.isEmpty ? (500, [:]) : state.submissions.removeFirst()
            case "/widget/config":
                return (200, FormTests.config)
            default:
                return (404, [:])
            }
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (try JSONSerialization.data(withJSONObject: body), response)
    }
}

/// A transport with no network at all.
struct OfflineTransport: FaroTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        throw URLError(.notConnectedToInternet)
    }
}

final class SendTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        Faro.identify(nil)
        Faro.clearBreadcrumbs()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        Faro.identify(nil)
        Faro.clearBreadcrumbs()
    }

    private func faro(_ transport: any FaroTransport, app: String? = "parques") -> Faro {
        Faro(
            configuration: FaroConfiguration(key: "wk_test", app: app, locale: "es"),
            transport: transport, cacheDirectory: directory, minimumProofWait: 0
        )
    }

    private static var ok: (Int, [String: Any]) {
        (200, ["success": true, "ticket": ["number": 42, "email": "ana@example.com", "confirmed": false]])
    }

    private static func error(_ status: Int, _ code: String, _ message: String) -> (Int, [String: Any]) {
        (status, ["errorCode": code, "errorNumber": status * 1000 + 1, "message": message])
    }

    private func json(_ call: FakeTransport.Call) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: call.body) as? [String: Any])
    }

    func testSendsJSONWithEverything() async throws {
        let transport = FakeTransport(submissions: [Self.ok])
        let client = faro(transport)
        Faro.identify(FaroUser(id: "u1", email: "ana@example.com", name: "Ana"))
        Faro.breadcrumb("Opened   the shop\n")
        Faro.breadcrumb(String(repeating: "x", count: 300))

        let ticket = try await client.send(
            FaroRequest(kind: .problem, message: " The board froze ", fields: ["where": "online"],
                        device: ["plan": "pro"])
        )
        XCTAssertEqual(ticket, FaroTicket(number: 42, email: "ana@example.com", isConfirmed: false))

        let post = try XCTUnwrap(transport.posts.first)
        XCTAssertEqual(post.request.httpMethod, "POST")
        XCTAssertEqual(post.request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try json(post)
        XCTAssertEqual(body["key"] as? String, "wk_test")
        XCTAssertEqual(body["app"] as? String, "parques")
        XCTAssertEqual(body["platform"] as? String, "ios")
        XCTAssertEqual(body["kind"] as? String, "problem")
        XCTAssertEqual(body["message"] as? String, "The board froze")
        // Filled in from the identified user; unsigned, so no `user` object.
        XCTAssertEqual(body["email"] as? String, "ana@example.com")
        XCTAssertEqual(body["name"] as? String, "Ana")
        XCTAssertNil(body["user"])
        XCTAssertEqual(body["locale"] as? String, "es")
        XCTAssertEqual(body["website"] as? String, "")
        XCTAssertEqual(body["fields"] as? [String: String], ["where": "online"])
        let device = try XCTUnwrap(body["device"] as? [String: String])
        XCTAssertEqual(device["plan"], "pro")
        XCTAssertEqual(device["manufacturer"], "Apple")
        XCTAssertEqual(device["sdk"], "faro-ios \(Faro.version)")
        XCTAssertLessThanOrEqual(device.count, 12)
        let proof = try XCTUnwrap(body["proof"] as? [String: Any])
        XCTAssertEqual(proof["number"] as? Int, 1_001)
        XCTAssertEqual(proof["signature"] as? String, "sig1")
        let crumbs = try XCTUnwrap((body["context"] as? [String: Any])?["breadcrumbs"] as? [[String: Any]])
        XCTAssertEqual(crumbs.count, 2)
        XCTAssertEqual(crumbs[0]["text"] as? String, "Opened the shop")
        XCTAssertEqual((crumbs[1]["text"] as? String)?.count, FaroBreadcrumb.maxLength)
        XCTAssertEqual(crumbs[0]["ago"] as? Int, 0)
        // The newest that fit in 120 characters, for the panel today; unsigned user id too.
        XCTAssertEqual(device["trail"], "Opened the shop › " + String(repeating: "x", count: 60))
        XCTAssertEqual(device["userId"], "u1")
    }

    func testSignedUserTravels() async throws {
        let transport = FakeTransport(submissions: [Self.ok])
        Faro.identify(FaroUser(id: "u1", email: "ana@example.com", name: "Ana", signature: "abc123"))
        try await faro(transport, app: nil).send(FaroRequest(kind: .question, message: "How do I play?"))
        let body = try json(XCTUnwrap(transport.posts.first))
        XCTAssertNil(body["app"])
        XCTAssertNil((body["device"] as? [String: String])?["userId"])
        let user = try XCTUnwrap(body["user"] as? [String: String])
        XCTAssertEqual(user, ["id": "u1", "email": "ana@example.com", "name": "Ana", "signature": "abc123"])
    }

    func testKeepsTheProofAfterAValidationError() async throws {
        let transport = FakeTransport(submissions: [
            Self.error(400, "INVALID_FORM", "field: where"), Self.ok,
        ])
        let client = faro(transport)
        client.prepare()
        let request = FaroRequest(kind: .problem, message: "It broke", email: "ana@example.com")
        do {
            try await client.send(request)
            XCTFail("Expected INVALID_FORM")
        } catch FaroError.invalidForm(let field) {
            XCTAssertEqual(field, "where")
        }
        try await client.send(request)
        // One puzzle served both attempts; a new one is prepared after the success.
        let proofs = try transport.posts.map { try XCTUnwrap(json($0)["proof"] as? [String: Any])["challenge"] as? String }
        XCTAssertEqual(proofs.count, 2)
        XCTAssertEqual(proofs[0], proofs[1])
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(transport.challenges, 2)
    }

    func testRetriesOnceWithANewProof() async throws {
        let transport = FakeTransport(submissions: [Self.error(400, "SPAM_CHECK_FAILED", "proof: reused"), Self.ok])
        let ticket = try await faro(transport).send(FaroRequest(kind: .problem, message: "Hello", email: "a@b.co"))
        XCTAssertEqual(ticket.number, 42)
        let challenges = try transport.posts.map {
            try XCTUnwrap(json($0)["proof"] as? [String: Any])["challenge"] as? String
        }
        XCTAssertEqual(challenges.count, 2)
        XCTAssertNotEqual(challenges[0], challenges[1])
    }

    func testGivesUpAfterTheRetry() async throws {
        let transport = FakeTransport(submissions: [
            Self.error(400, "SPAM_CHECK_FAILED", "proof: too_fast"),
            Self.error(400, "SPAM_CHECK_FAILED", "proof: expired"),
        ])
        do {
            try await faro(transport).send(FaroRequest(kind: .problem, message: "Hello", email: "a@b.co"))
            XCTFail("Expected SPAM_CHECK_FAILED")
        } catch let error as FaroError {
            XCTAssertEqual(error, .spamCheck(reason: "expired"))
        }
        XCTAssertEqual(transport.posts.count, 2)
    }

    func testDropsTheProofAfterAServerError() async throws {
        let transport = FakeTransport(submissions: [Self.error(500, "INTERNAL_ERROR", "Error interno"), Self.ok])
        let client = faro(transport)
        let request = FaroRequest(kind: .problem, message: "Hello", email: "a@b.co")
        await XCTAssertThrowsFaroError(try await client.send(request), .server(status: 500, code: "INTERNAL_ERROR",
                                                                           message: "Error interno"))
        try await client.send(request)
        let challenges = try transport.posts.map {
            try XCTUnwrap(json($0)["proof"] as? [String: Any])["challenge"] as? String
        }
        XCTAssertNotEqual(challenges[0], challenges[1])
    }

    func testMultipartWithAttachments() async throws {
        let transport = FakeTransport(submissions: [Self.ok])
        let image = try FaroAttachment(imageData: AttachmentTests.png(width: 40, height: 20))
        try await faro(transport).send(
            FaroRequest(kind: .problem, message: "See the capture", email: "a@b.co", attachments: [image, image])
        )
        let post = try XCTUnwrap(transport.posts.first)
        let contentType = try XCTUnwrap(post.request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="))
        let boundary = String(contentType.dropFirst("multipart/form-data; boundary=".count))
        let text = String(decoding: post.body, as: UTF8.self)
        XCTAssertEqual(text.components(separatedBy: "--\(boundary)\r\n").count - 1, 3)
        XCTAssertTrue(text.contains("Content-Disposition: form-data; name=\"data\"\r\n\r\n{"))
        XCTAssertEqual(text.components(separatedBy: "name=\"file\"; filename=\"image.jpg\"\r\nContent-Type: image/jpeg").count - 1, 2)
        XCTAssertTrue(text.hasSuffix("--\(boundary)--\r\n"))
    }

    func testRejectsTooManyAttachmentsLocally() async throws {
        let transport = FakeTransport(submissions: [Self.ok])
        let image = try FaroAttachment(imageData: AttachmentTests.png(width: 4, height: 4))
        let request = FaroRequest(kind: .problem, message: "Hello", email: "a@b.co",
                                  attachments: [image, image, image, image])
        await XCTAssertThrowsFaroError(try await faro(transport).send(request), .invalidAttachment)
        XCTAssertTrue(transport.calls.isEmpty)
    }

    func testNotConfigured() async {
        let client = Faro(configuration: FaroConfiguration(key: "  "))
        await XCTAssertThrowsFaroError(try await client.form(), .notConfigured)
        await XCTAssertThrowsFaroError(try await client.send(FaroRequest(kind: .problem, message: "x")), .notConfigured)
    }

    func testFormIsCachedAndServedOffline() async throws {
        let online = faro(FakeTransport(submissions: []))
        let fresh = try await online.form(locale: "en")
        XCTAssertEqual(fresh.source, .network)
        XCTAssertEqual(fresh.title, "Write to us")

        let offline = faro(OfflineTransport())
        let cached = try await offline.form(locale: "en")
        XCTAssertEqual(cached.source, .cache)
        XCTAssertEqual(cached.fields, fresh.fields)
        XCTAssertEqual(offline.cachedForm(locale: "es")?.title, "Escríbenos")

        try? FileManager.default.removeItem(at: directory)
        do {
            _ = try await offline.form()
            XCTFail("Expected a network error")
        } catch let error as FaroError {
            XCTAssertTrue(error.isNetwork)
        }
    }

    func testRequestsTheRightURLs() async throws {
        let transport = FakeTransport(submissions: [Self.ok])
        let client = faro(transport)
        _ = try await client.form()
        try await client.send(FaroRequest(kind: .problem, message: "Hello", email: "a@b.co"))
        let urls = transport.calls.map { $0.request.url!.absoluteString }
        XCTAssertTrue(urls.contains("https://api-faro.pixeldunord.com/widget/config?key=wk_test&app=parques"))
        XCTAssertTrue(urls.contains("https://api-faro.pixeldunord.com/widget/challenge?key=wk_test"))
        XCTAssertTrue(urls.contains("https://api-faro.pixeldunord.com/widget/requests"))
    }
}

func XCTAssertThrowsFaroError<T>(
    _ expression: @autoclosure () async throws -> T,
    _ expected: FaroError,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected \(expected)", file: file, line: line)
    } catch let error as FaroError {
        XCTAssertEqual(error, expected, file: file, line: line)
    } catch {
        XCTFail("Unexpected \(error)", file: file, line: line)
    }
}
