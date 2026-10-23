# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

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

[1.0.0]: https://github.com/Pixel-Du-Nord/faro-ios/releases/tag/1.0.0
