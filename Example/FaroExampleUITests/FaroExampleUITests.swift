import XCTest

/**
 Drives the ready-made help screen end to end, against the configured Faro.

 Environment (pass with the `TEST_RUNNER_` prefix to `xcodebuild test`):
 - `FARO_SHOTS`: a folder to save screenshots in.
 - `FARO_SEND=1`: really send the request (otherwise it stops right before).
 - `FARO_EMAIL`: the reply address to type.
 - `FARO_LOCALE`: the app language (`es` by default).
 */
@MainActor
final class FaroExampleUITests: XCTestCase {
    private let app = XCUIApplication()
    private let env = ProcessInfo.processInfo.environment

    private func launch() {
        continueAfterFailure = false
        app.launchArguments += ["-faro.locale", env["FARO_LOCALE"] ?? "es", "-faro.app", "parques",
                                // The screen remembers the last address typed: start empty.
                                "-com.pixeldunord.faro.lastEmail", "", "-com.pixeldunord.faro.lastName", ""]
        app.launch()
    }

    private func shot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let folder = env["FARO_SHOTS"], !folder.isEmpty {
            try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(name).png"))
        }
    }

    func testFileARequestWithTheReadyMadeScreen() throws {
        launch()
        // Leave a couple of breadcrumbs, then open help from the lobby.
        app.buttons["example.table.Mesa Roja"].firstMatch.tap()
        app.buttons["example.table.Mesa Verde"].firstMatch.tap()
        shot("01-lobby")
        app.buttons["example.help"].tap()

        let problem = app.buttons["faro.kind.problem"]
        XCTAssertTrue(problem.waitForExistence(timeout: 20), "The form did not load")
        sleep(1)
        shot("02-form")

        problem.tap()
        let online = app.buttons["faro.option.where.online"]
        if online.exists { online.tap() }

        let message = app.textViews["faro.field.message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        message.tap()
        message.typeText("Prueba del SDK de iOS: envío real desde el simulador con captura tapada. Se puede borrar.")

        let email = app.textFields["faro.field.email"]
        email.tap()
        email.typeText(env["FARO_EMAIL"] ?? "faro-prueba+sdk-ios@pixeldunord.com")
        shot("03-filled")

        // Cover the player card on the screenshot.
        let edit = app.buttons["faro.screenshot.edit"]
        edit.swipeUpIfNeeded(in: app)
        edit.tap()
        let canvas = app.otherElements["faro.editor.canvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        for y in [0.215, 0.25, 0.285] {
            canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: y))
                .press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: y)))
        }
        shot("04-editor")
        app.buttons["faro.editor.done"].tap()

        let send = app.buttons["faro.send"]
        send.swipeUpIfNeeded(in: app)
        shot("05-ready")

        guard env["FARO_SEND"] == "1" else { return }
        send.tap()
        let number = app.staticTexts["faro.success.number"]
        XCTAssertTrue(number.waitForExistence(timeout: 60), "No ticket number")
        sleep(1)
        shot("06-success")
        print("FARO_TICKET \(number.label)")
        if let folder = env["FARO_SHOTS"] {
            try? number.label.write(toFile: folder + "/ticket.txt", atomically: true, encoding: .utf8)
        }
    }
}

@MainActor
private extension XCUIElement {
    /// Scrolls the screen up until the element is on screen (a few tries at most).
    func swipeUpIfNeeded(in app: XCUIApplication) {
        var tries = 0
        while !isHittable && tries < 6 {
            app.swipeUp()
            tries += 1
        }
    }
}
