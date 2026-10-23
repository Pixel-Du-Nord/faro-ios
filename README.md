# Faro for iOS

In-app help and feedback for iOS apps, backed by [Faro](https://faro.pixeldunord.com), the support desk by Pixel du Nord.

People report a problem, suggest an idea or ask a question from inside your app. The request reaches your team's Faro panel with the app version, the OS and the device model (and, if they want, a screenshot with private data covered), and you answer by email from there.

- **`Faro`**: the core. Foundation + CryptoKit, no UI. Fetches the form you define in the Faro panel, solves the anti-spam proof of work, sends requests with images, and gives you typed errors.
- **`FaroUI`**: a ready-made SwiftUI screen drawn from that form, with a screenshot editor to cover private data, photo picking, every loading and error state, VoiceOver, Dynamic Type, light and dark mode, and texts in English, Spanish and Portuguese.

iOS 15+, Swift 5.9+, no third-party dependencies. Strict-concurrency clean (`Sendable` throughout).

## Installation

Swift Package Manager. In Xcode, **File → Add Package Dependencies…** and enter:

```
https://github.com/Pixel-Du-Nord/faro-ios
```

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Pixel-Du-Nord/faro-ios", from: "1.0.1"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "Faro", package: "faro-ios"),
        .product(name: "FaroUI", package: "faro-ios"),   // optional
    ]),
]
```

Your organization needs the **Requests** module in Faro. Your key (`wk_…`) is in **Widget → Installation**; it is public by design. If you have several apps, create each one in **Organization → Applications** and pass its slug as `app`: requests are filed per app and each app can have its own form.

## Configuration

Once, at launch:

```swift
import Faro

@main
struct MyApp: App {
    init() {
        Faro.configure(key: "wk_…", app: "my-app")
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
```

| Parameter | |
|---|---|
| `key` | Your public widget key. |
| `app` | The application's slug in Faro. Optional. |
| `locale` | The default language (`"es"`, `"pt-BR"`, cut to its base: `"pt"`), for calls that do not name one. `nil` uses the device's. |
| `apiURL` | Leave the default (`https://api-faro.pixeldunord.com`). |

If your app has its own language setting, do not configure again when it changes: pass the language with each call instead (`form(locale:)`, `FaroRequest.locale` or `form.request(…)`, `FaroHelpView(locale:)`). If `configure` is called again, `Faro.shared` becomes a new client; an instance you already hold keeps working with its own configuration.

## The ready-made screen

```swift
import FaroUI

struct ContentView: View {
    @State private var showHelp = false

    var body: some View {
        Button("Help & feedback") { showHelp = true }
            .faroHelpSheet(isPresented: $showHelp)
    }
}
```

`faroHelpSheet` takes a screenshot of what is on screen **before** the sheet slides in and offers it as the first attachment. The person can draw over it to cover private data, leave it out, or add up to two photos from their library (the system picker: no photo-library permission needed).

To present it yourself:

```swift
Button("Help") {
    screenshot = FaroScreenshot.captureKeyWindow()   // before presenting
    showHelp = true
}
.sheet(isPresented: $showHelp) {
    FaroHelpView(
        screenshot: screenshot,
        prefill: FaroPrefill(kind: .problem, fields: ["where": "checkout"]),
        device: ["plan": "pro"],
        onSent: { ticket in print("Request #\(ticket.number)") },
        onClose: { showHelp = false }
    )
}
```

The screen is drawn from your form in the Faro panel: request kinds as a selector, lists as chips (a menu when long, with their groups), and text, multi-line, checkbox, number, phone, URL and date fields, in your order and your languages. Change the form in the panel and the app follows, no release needed. The last form is cached on disk, so the screen shows instantly and works offline once it has been seen.

### Shake to report

```swift
RootView()
    .faroShakeToReport()
```

Listens to the accelerometer (no permission needed) only while the view is on screen, and opens the help screen with a screenshot and the *problem* kind selected (pass your own `prefill` to change it). The simulator has no accelerometer; keep a button too.

### Texts

The texts your team writes in Faro (title, labels, options, the send button, the success message) always win. The rest (the names of the kinds, hints, notices, buttons) are `FaroStrings`, built in for English, Spanish and Portuguese and picked by language. For another language, or your own wording, copy one and change what you need:

```swift
var strings = FaroStrings.english
strings.kindProblem = "Report a bug"
strings.send = "Send report"

FaroHelpView(strings: strings) { showHelp = false }
// or .faroHelpSheet(isPresented: $showHelp, strings: strings), .faroShakeToReport(strings: strings)
```

## Theme

```swift
FaroHelpView { showHelp = false }
    .faroTheme(accent: .indigo, shape: .pill, typography: .rounded)
```

| | |
|---|---|
| `accent` | Selected options, the send button, links. `nil` uses your organization's brand color from the Faro panel, then your app's tint. Light accents are darkened for text in light mode, and text on the accent turns black or white for contrast. |
| `shape` | `.rounded` (default), `.square`, `.pill`. |
| `typography` | `.system`, `.rounded`, `.serif`, `.monospaced` or `.custom("YourFont-Regular")`. All follow Dynamic Type. |

Apply it once at the root (`.faroTheme(...)` on your `TabView`/`WindowGroup` content) and every FaroUI view inside picks it up.

## The core with your own UI

```swift
import Faro

// When your screen opens. appLanguage: your app's own language ("es", "pt-BR"…), or nil.
let form = try await Faro.shared.form(locale: appLanguage)  // or cachedForm(locale:) to draw instantly
Faro.shared.prepare()                         // starts the anti-spam proof in the background
// Offline with nothing cached: FaroForm.fallback(locale:) is a minimal form for your own labels.

// Draw form.kinds and form.fields (already in the right language, in order).
// Keep what is typed by field key: "message", "email", "name" and your own keys.

// When the person taps Send.
let issues = form.validate(kind: kind, values: values)   // Faro's own rules, locally
guard issues.isEmpty else { return show(issues) }

let screenshot = try FaroAttachment(image: capture)      // JPEG, ≤2048 px, ≤3 MB
let ticket = try await Faro.shared.send(
    form.request(kind: kind, values: values, attachments: [screenshot])
)

// When your screen closes.
Faro.shared.cancelPending()   // stops a proof still being solved (a solved one is kept)
```

- `form.inLocale(_:)` gives the same form in another language without the network.
- `form.request(kind:values:attachments:)` puts `message`, `email` and `name` in their own properties, the rest through `customValues(_:)`, and the form's language for the emails.
- `send` checks the message (3 to 4000 characters) and the email before any network call and throws the same errors Faro would, so a typo does not count against the hourly limit.

### Sending without a name

`FaroRequest.name = nil` uses the identified person's name; `""` sends no name at all, even for an identified person. `form.request` follows what the person saw: with the name turned off in the form, or emptied by the person, the request has no name.

Or build the request by hand:

```swift
try await Faro.shared.send(FaroRequest(
    kind: .problem,
    message: "The sync button does nothing",
    email: "ana@example.com",
    fields: ["where": "settings"],
    device: ["plan": "pro"]
))
```

About the proof of work: Faro asks for a small SHA-256 puzzle instead of a captcha, and does not accept its solution until 3 seconds after handing it out. Call `prepare()` when your screen opens and the request goes out the moment the person taps Send. `send` handles the rest: it waits whatever is left of the 3 s, keeps the same proof after a validation error so a corrected request does not wait again, starts the next one right after a success, and retries once with a fresh one if Faro rejects it. A `send` waiting for a proof that `cancelPending()` stopped simply makes another.

## Screenshots

`FaroScreenshot.captureKeyWindow()` returns the key window as a `UIImage` (at most 2x), or `nil`. `FaroScreenshot.capture(_ view: UIView)` captures any view. Take it before presenting your help screen. Secure text fields render as dots. Nothing is captured or sent on its own: the person sees the image and decides.

In FaroUI, *Cover private info* opens an editor with three tools: a thick marker (three sizes) and boxes to cover names, numbers or faces, and a thin pen in the accent color to point at what went wrong. What is drawn is burnt into the image on the device; the original never leaves it.

`FaroAttachment(imageData:)`, `FaroAttachment(image:)` and `FaroAttachment(cgImage:)` turn any image into what Faro takes: JPEG, orientation applied, transparency flattened on white, at most 2048 px on the long side and 3 MB. Up to 3 per request.

## Identifying the person

```swift
Faro.identify(FaroUser(id: user.id, email: user.email, name: user.name))  // every part is optional
// On sign-out:
Faro.identify(nil)
```

Without a signature, the email and name prefill the form and are used when a request has none. With a `signature`, the HMAC-SHA256 of `id` with your widget's identity secret in hex, **computed by your server** (never ship the secret), the request is linked to the person's contact in Faro and their email counts as confirmed. See the Identity guide in the Faro docs. The user is kept in memory only.

## Breadcrumbs

```swift
Faro.breadcrumb("Opened Settings")
Faro.breadcrumb("Tapped Sync (offline)")
```

The last 20, each up to 60 characters, travel with the next request so the team sees what led to it: all of them as `context.breadcrumbs` (`{ "text": …, "ago": seconds }`) and the newest ones that fit in 120 characters, joined with ` › `, as the `trail` device fact. They live in memory only. Never put personal data, tokens or secrets in them. `Faro.clearBreadcrumbs()` forgets them; `FaroRequest.includesBreadcrumbs = false` leaves them out of one request.

## Errors

Every failure is a `FaroError`, told apart by Faro's `errorCode`:

| Case | `errorCode` | What to do |
|---|---|---|
| `.network(_)` | `NETWORK` | Offline or timed out. Retry. |
| `.invalidForm(field:)` | `INVALID_FORM` | Highlight `field`: `"kind"`, `"name"` or one of your keys. |
| `.invalidEmail` | `INVALID_EMAIL_FORMAT` | Highlight the email. |
| `.invalidMessage` | `INVALID_TEXT` | Message under 3 or over 4000 characters. |
| `.rateLimited` | `RATE_LIMITED` | More than 3 an hour from one address, or 6 from one network. Later. |
| `.spamCheck(reason:)` | `SPAM_CHECK_FAILED` | The proof failed even after the automatic retry. Try again. |
| `.fileTooLarge`, `.fileTypeNotAllowed`, `.invalidAttachment` | | An image is too big, not an image, or there are more than 3. |
| `.moduleRequired` | `MODULE_REQUIRED` | The organization lacks the Requests module. |
| `.widgetNotFound`, `.subscriptionInactive` | | Wrong key, or the organization is not active. |
| `.notConfigured` | | `Faro.configure` was not called. |
| `.server(status:code:message:)` | any other | Anything else Faro answered. |

`error.code`, `error.status`, `error.isNetwork` and `error.isValidation` help when you only need the broad strokes.

## Privacy

What a request carries:

- What the person typed: kind, message, email, name and your form's fields.
- The images they chose to attach (the screenshot only if they leave it on).
- Device facts: `appVersion`, `build`, `os`, `osVersion`, `model` (the hardware identifier, like `iPhone16,2`), `manufacturer`, `locale`, `timezone`, `screen` (pixels and scale, like `1179x2556 @3x`), `sdk`, plus any you add (Faro keeps 12). `Faro.deviceFacts()` returns exactly what a request sent now would carry.
- The breadcrumbs you recorded (as `context.breadcrumbs`, `{ text, ago }`, and the newest ones joined in the `trail` device fact, up to 120 characters, which is what the Faro panel shows today).
- The user you identified: signed, as `user`; unsigned, only their id as the `userId` device fact (plus the email and name, if the request has none).
- The language for the reply emails (its base: `pt`, not `pt-BR`).

What it never carries: device or advertising identifiers, location, contacts, IP lookups, or anything else from the device. There is no tracking and no analytics. The SDK stores only the cached form (Caches) and, in FaroUI, the last email and name typed (`UserDefaults`, to prefill next time; not when you call `identify`). Both targets ship a privacy manifest (`PrivacyInfo.xcprivacy`) declaring the data above as linked to the user, for app functionality, not tracking, and the required-reason APIs used (system uptime to time the proof of work; `UserDefaults`). It includes the User ID, which is only collected when your app calls `Faro.identify(_:)` with an `id`.

Requests are sent over HTTPS to `api-faro.pixeldunord.com`, hosted on AWS in the United States.

## API

| Core (`Faro`) | |
|---|---|
| `Faro.configure(key:app:locale:apiURL:)` | Set up `Faro.shared`. |
| `Faro.shared`, `Faro(configuration:)` | The client. |
| `form(locale:) async throws -> FaroForm` | The form, fresh (or cached if offline). |
| `cachedForm(locale:) -> FaroForm?` | The cached form, instantly. |
| `prepare()`, `cancelPending()` | Warm up the proof of work; stop one being solved. |
| `send(_:) async throws -> FaroTicket` | File a request. |
| `Faro.identify(_:)`, `Faro.currentUser` | The person using the app. |
| `Faro.breadcrumb(_:)`, `Faro.breadcrumbs`, `Faro.clearBreadcrumbs()` | Recent actions. |
| `FaroForm` | `kinds`, `fields`, texts, `validate(kind:values:)`, `request(kind:values:attachments:)`, `customValues(_:)`, `inLocale(_:)`, `fallback(locale:)`. |
| `FaroFormField`, `FaroFieldType`, `FaroFieldOption`, `FaroOptionGroup`, `FaroFieldIssue` | The fields. |
| `FaroRequest`, `FaroKind`, `FaroAttachment`, `FaroTicket`, `FaroUser`, `FaroBreadcrumb` | What goes and comes back. |
| `Faro.deviceFacts(adding:includesBreadcrumbs:)`, `FaroDevice.automatic()`, `FaroDevice.modelIdentifier` | The device facts. |
| `FaroScreenshot.captureKeyWindow()`, `capture(_:)` | Screenshots (UIKit). |
| `FaroError` | Typed errors. |
| `FaroLocale.language(_:)` | The base language of a tag (`pt-BR` → `pt`). |

| UI (`FaroUI`) | |
|---|---|
| `FaroHelpView(faro:locale:screenshot:prefill:device:strings:onSent:onClose:)` | The ready-made screen. |
| `.faroHelpSheet(isPresented:…)` | The screen in a sheet, screenshot included. |
| `.faroShakeToReport(…)` | Shake to open it. |
| `.faroTheme(_:)`, `FaroTheme` | Accent, shape, typography. |
| `FaroPrefill` | Initial values. |
| `FaroStrings` | The screen's own texts (`.english`, `.spanish`, `.portuguese`, `forLocale(_:)`). |

## Example app

`Example/` has a small app (a made-up game lobby) that files real requests to Pixel du Nord's Faro, with the ready-made screen, the core under a plain UI of its own, and settings for the key, app, language, identity and theme:

```sh
cd Example
xcodegen generate
open FaroExample.xcodeproj
```

Its UI test (`FaroExampleUITests`) walks the whole screen; it only sends when run with `TEST_RUNNER_FARO_SEND=1`.

Run the core's tests with `swift test`.

## License

MIT © Pixel du Nord LLC. See [LICENSE](LICENSE).
