import CoreGraphics
import ImageIO
import XCTest
@testable import Faro

final class ProofOfWorkTests: XCTestCase {
    /// Computed independently: `printf '%s' "$salt$n" | shasum -a 256`.
    private let salt = "kq3v9d0s1x7m2b4n?k=wk_test&t=1792720083783&"

    func testSolvesAKnownVector() throws {
        let challenge = "1362e273a07cbfbb96adfff04bc235df7070af4855a356c5d969ba7521cdea47"
        XCTAssertEqual(try ProofOfWork.solve(salt: salt, challenge: challenge, max: 50_000), 31_337)
    }

    func testFindsTheEdges() throws {
        XCTAssertEqual(
            try ProofOfWork.solve(salt: salt, challenge: "75b3034f55476bacacdb301bc1adfb17db70cad914bd62032279cb01bf35efa2",
                                  max: 50_000), 0)
        XCTAssertEqual(
            try ProofOfWork.solve(salt: salt, challenge: "1345F79665BA68CC8148FA80F6362EA4EFD6EC7D8D16DB54A9A867A940E6BBD6",
                                  max: 50_000), 50_000)
    }

    func testNoSolutionWithinRange() throws {
        let challenge = "1362e273a07cbfbb96adfff04bc235df7070af4855a356c5d969ba7521cdea47"
        XCTAssertNil(try ProofOfWork.solve(salt: salt, challenge: challenge, max: 31_336))
        XCTAssertNil(try ProofOfWork.solve(salt: salt, challenge: "zz", max: 10))
        XCTAssertNil(try ProofOfWork.solve(salt: salt, challenge: "abcd", max: 10))
    }

    func testStopsWhenCancelled() async {
        let task = Task {
            try ProofOfWork.solve(salt: "x", challenge: String(repeating: "0", count: 64), max: 50_000_000)
        }
        task.cancel()
        let result = await task.result
        XCTAssertThrowsError(try result.get()) { XCTAssertTrue($0 is CancellationError) }
    }
}

final class ErrorMappingTests: XCTestCase {
    func testMapsFaroCodes() {
        XCTAssertEqual(FaroError.from(status: 400, code: "INVALID_FORM", message: "field: where"),
                       .invalidForm(field: "where"))
        XCTAssertEqual(FaroError.from(status: 400, code: "INVALID_FORM", message: "Falta un dato"),
                       .invalidForm(field: ""))
        XCTAssertEqual(FaroError.from(status: 400, code: "INVALID_EMAIL_FORMAT", message: nil), .invalidEmail)
        XCTAssertEqual(FaroError.from(status: 400, code: "INVALID_TEXT", message: "x"), .invalidMessage)
        XCTAssertEqual(FaroError.from(status: 429, code: "RATE_LIMITED", message: nil), .rateLimited)
        XCTAssertEqual(FaroError.from(status: 429, code: nil, message: nil), .rateLimited)
        XCTAssertEqual(FaroError.from(status: 400, code: "SPAM_CHECK_FAILED", message: "proof: too_fast"),
                       .spamCheck(reason: "too_fast"))
        XCTAssertEqual(FaroError.from(status: 413, code: "FILE_TOO_LARGE", message: nil), .fileTooLarge)
        XCTAssertEqual(FaroError.from(status: 415, code: "FILE_TYPE_NOT_ALLOWED", message: nil), .fileTypeNotAllowed)
        XCTAssertEqual(FaroError.from(status: 403, code: "MODULE_REQUIRED", message: nil), .moduleRequired)
        XCTAssertEqual(FaroError.from(status: 404, code: "WIDGET_NOT_FOUND", message: nil), .widgetNotFound)
        XCTAssertEqual(FaroError.from(status: 403, code: "SUBSCRIPTION_INACTIVE", message: nil), .subscriptionInactive)
        XCTAssertEqual(FaroError.from(status: 502, code: nil, message: nil),
                       .server(status: 502, code: "HTTP_502", message: ""))
    }

    func testCodesStatusesAndProofRules() {
        XCTAssertEqual(FaroError.invalidForm(field: "x").code, "INVALID_FORM")
        XCTAssertEqual(FaroError.invalidForm(field: "x").status, 400)
        XCTAssertEqual(FaroError.network("offline").code, "NETWORK")
        XCTAssertNil(FaroError.network("offline").status)
        XCTAssertTrue(FaroError.network("offline").isNetwork)
        XCTAssertTrue(FaroError.invalidEmail.isValidation)
        XCTAssertFalse(FaroError.rateLimited.isValidation)
        XCTAssertTrue(FaroError.rateLimited.leavesProofUnspent)
        XCTAssertTrue(FaroError.invalidMessage.leavesProofUnspent)
        XCTAssertFalse(FaroError.spamCheck(reason: "reused").leavesProofUnspent)
        XCTAssertFalse(FaroError.server(status: 500, code: "INTERNAL_ERROR", message: "").leavesProofUnspent)
        XCTAssertNotNil(FaroError.moduleRequired.errorDescription)
    }

    func testHTTPLayerMapsTransportFailures() async {
        do {
            _ = try await HTTP.json(URLRequest(url: URL(string: "https://example.com")!), transport: OfflineTransport())
            XCTFail("Expected a network error")
        } catch let error as FaroError {
            XCTAssertTrue(error.isNetwork)
        } catch {
            XCTFail("Unexpected \(error)")
        }
    }
}

final class AttachmentTests: XCTestCase {
    /// A PNG with transparency, drawn in memory.
    static func png(width: Int, height: Int) -> Data {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 0.5))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        let image = context.makeImage()!
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    func testReducesToAJPEGWithinTheLimits() throws {
        let attachment = try FaroAttachment(imageData: Self.png(width: 3200, height: 1800), filename: "My \"shot\".png")
        XCTAssertEqual(attachment.mimeType, "image/jpeg")
        XCTAssertEqual(attachment.filename, "Myshot.jpg")
        XCTAssertEqual(attachment.pixelWidth, 2048)
        XCTAssertEqual(attachment.pixelHeight, 1152)
        XCTAssertLessThanOrEqual(attachment.data.count, FaroAttachment.maxBytes)
        XCTAssertEqual(Array(attachment.data.prefix(3)), [0xFF, 0xD8, 0xFF])
    }

    func testKeepsSmallImagesTheirSize() throws {
        let attachment = try FaroAttachment(imageData: Self.png(width: 300, height: 600))
        XCTAssertEqual(attachment.pixelWidth, 300)
        XCTAssertEqual(attachment.pixelHeight, 600)
    }

    func testRejectsWhatIsNotAnImage() {
        XCTAssertThrowsError(try FaroAttachment(imageData: Data("hello".utf8))) {
            XCTAssertEqual($0 as? FaroError, .invalidAttachment)
        }
    }
}

final class DeviceTests: XCTestCase {
    func testAutomaticFactsAndTheLimit() {
        let facts = FaroDevice.facts(adding: [
            "plan": "pro", "a1": "1", "a2": "2", "a3": "3", "a4": "4", "a5": "5", "app": "spoofed", "empty": " ",
        ])
        XCTAssertEqual(facts["manufacturer"], "Apple")
        XCTAssertEqual(facts["sdk"], "faro-ios \(Faro.version)")
        XCTAssertNotNil(facts["os"])
        XCTAssertNotNil(facts["osVersion"])
        XCTAssertNotNil(facts["timezone"])
        XCTAssertFalse(FaroDevice.modelIdentifier.isEmpty)
        XCTAssertLessThanOrEqual(facts.count, FaroDevice.maxFacts)
        XCTAssertNil(facts["app"])
        XCTAssertNil(facts["empty"])
        // Every automatic fact survives the app's extras.
        for key in FaroDevice.automatic().keys { XCTAssertNotNil(facts[key], key) }
    }

    func testTrailKeepsTheNewestThatFit() {
        let crumbs = ["Opened shop", "Tapped buy", "Paid"].map { FaroBreadcrumb(message: $0) }
        XCTAssertEqual(BreadcrumbTrail.trail(crumbs), "Opened shop › Tapped buy › Paid")
        XCTAssertEqual(BreadcrumbTrail.trail(crumbs, max: 20), "Tapped buy › Paid")
        XCTAssertEqual(BreadcrumbTrail.trail([FaroBreadcrumb(message: "abcdef")], max: 3), "abc")
        XCTAssertEqual(BreadcrumbTrail.trail([]), "")
    }

    func testBreadcrumbTrailKeepsTheLastOnes() {
        let trail = BreadcrumbTrail()
        for i in 1...25 { trail.add("step \(i)") }
        trail.add("   ")
        XCTAssertEqual(trail.all.count, FaroBreadcrumb.limit)
        XCTAssertEqual(trail.all.first?.message, "step 6")
        XCTAssertEqual(trail.all.last?.message, "step 25")
        trail.clear()
        XCTAssertTrue(trail.all.isEmpty)
    }
}
