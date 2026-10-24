# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [1.0.2] - 2026-10-23

### Changed

- `INVALID_FORM` and `SPAM_CHECK_FAILED` read the field and the reason from Faro's own `field` and
  `reason` properties. Answers from an older Faro, which carry them in the message
  (`"field: where"`, `"proof: expired"`), are still understood.

## [1.0.1] - 2026-10-22

### Added

- `FaroStrings` is public: the screen's own texts (kind names, hints, notices, buttons) can be
  replaced (`var s = FaroStrings.english; s.kindProblem = "…"`) and passed as `strings:` to
  `FaroHelpView`, `.faroHelpSheet` and `.faroShakeToReport`. Built in: `.english`, `.spanish`,
  `.portuguese`, `forLocale(_:)`.
- The screenshot editor has three tools, as on Android: the thick marker (three sizes), filled boxes
  and a thin pen in the accent color to point something out.
- `FaroForm.inLocale(_:)`: the same form in another language, without the network.
- `FaroForm.customValues(_:)`, as on Android.
- `Faro.cancelPending()`: stops a proof being solved (a solved one is kept); a `send` waiting for it
  makes another.
- `FaroUser.isSigned`.
- The `screen` device fact (`1179x2556 @3x`), as on Android.
- The privacy manifest declares the User ID (collected only when the app calls `identify` with an
  `id`).

### Changed

- `send` checks the message length and the email before any network call and throws
  `invalidMessage` / `invalidEmail`, as on Android, so a typo does not count against Faro's limit.
- `FaroUser.id` is optional, as on Android (`FaroUser(email:name:)` is enough to prefill).
- `FaroRequest.name = ""` sends no name, even for an identified person (before, an empty name took
  the identified person's). `nil` still uses it. `FaroForm.request` returns `""` when the form has
  the name turned off or the person emptied it, and `nil` only when `values` has no `name`.
- Images are scaled to 2048 px on the long side (was 1600), as on Android.
- `FaroForm.fallback(locale:)` lists message, email and name and follows `inLocale(_:)`.

## [1.0.0] - 2026-10-22

### Added

- `Faro` core: `Faro.configure(key:app:locale:apiURL:)`, `form(locale:)` with a disk cache of the
  last definition, `cachedForm(locale:)`, `prepare()`, `send(_:)`.
- Proof of work (SHA-256) solved in the background, with Faro's 3-second minimum, reuse after
  validation errors, renewal after a success, and one automatic retry on `SPAM_CHECK_FAILED`.
- Local validation with Faro's rules (`FaroForm.validate(kind:values:)`) and
  `FaroForm.request(kind:values:attachments:)`.
- Image attachments (up to 3) reduced to JPEG, at most 1600 px and 3 MB, sent as multipart.
- Automatic device facts with the real model identifier (also in the simulator).
- `Faro.identify(_:)` with optional server-side signature, and `Faro.breadcrumb(_:)`.
- Typed errors (`FaroError`) mapped from Faro's `errorCode`.
- `FaroScreenshot` to capture the key window or any view.
- `FaroUI`: `FaroHelpView` drawn from the form, with themes (`.faroTheme`), a screenshot editor to
  cover private data, the system photo picker, loading/offline/error/success states, VoiceOver and
  Dynamic Type, light and dark mode, and texts in English, Spanish and Portuguese.
- `.faroHelpSheet(isPresented:)` and `.faroShakeToReport()`.
- Privacy manifests for both targets.
- Example app (`Example/`, XcodeGen) and tests for the core.

[1.0.1]: https://github.com/Pixel-Du-Nord/faro-ios/releases/tag/1.0.1
[1.0.0]: https://github.com/Pixel-Du-Nord/faro-ios/releases/tag/1.0.0
