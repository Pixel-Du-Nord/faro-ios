import Foundation

/**
 Faro: in-app help and feedback for iOS, backed by the Faro support desk
 (the "Requests" module).

 A request filed through Faro reaches the team's panel with the app version,
 the operating system and the device model, and is answered by email from there.

 ```swift
 // Once, at launch.
 Faro.configure(key: "wk_…", app: "my-app")

 // When your help screen opens: fetch the form and warm up the anti-spam check.
 let form = try await Faro.shared.form()
 Faro.shared.prepare()

 // When the person taps Send.
 let ticket = try await Faro.shared.send(
     FaroRequest(kind: .problem, message: "The sync button does nothing", email: "ana@example.com")
 )
 print("Request #\(ticket.number)")
 ```

 Everything is `async` and safe to call from the main actor: the network and the
 proof of work run elsewhere. The type is `Sendable`, so an instance can be
 passed freely between tasks and actors.
 */
public final class Faro: Sendable {
    /// The SDK version, sent with every request as the `sdk` device fact.
    public static let version = "1.0.0"

    /// The settings this instance talks to Faro with.
    public let configuration: FaroConfiguration

    let transport: any FaroTransport
    let cache: FormCache
    let proofs: ProofStore

    /**
     Creates an independent client. Most apps call ``configure(key:app:locale:apiURL:)``
     once and use ``shared`` instead; a separate instance is useful when one app
     files requests for several Faro apps or organizations.
     */
    public convenience init(configuration: FaroConfiguration) {
        self.init(
            configuration: configuration,
            transport: URLSessionTransport(timeout: configuration.timeout),
            cacheDirectory: nil,
            minimumProofWait: ProofStore.serverMinimumWait
        )
    }

    init(
        configuration: FaroConfiguration,
        transport: any FaroTransport,
        cacheDirectory: URL?,
        minimumProofWait: TimeInterval
    ) {
        self.configuration = configuration
        self.transport = transport
        self.cache = FormCache(configuration: configuration, directory: cacheDirectory)
        let endpoints = Endpoints(configuration: configuration)
        self.proofs = ProofStore(minimumWait: minimumProofWait) {
            try await ProofOfWork.fetch(from: endpoints, transport: transport)
        }
    }

    // MARK: - The shared instance

    private static let current = Locked<Faro?>(nil)
    private static let unconfigured = Faro(configuration: FaroConfiguration(key: ""))

    /**
     Configures ``shared``. Call it once, early (for example in your `App`
     initializer). Calling it again replaces the shared client.

     - Parameters:
       - key: The public widget key of your organization (`wk_…`), from
         **Widget → Installation** in the Faro panel. It is public by design.
       - app: The slug of the application in Faro (**Organization → Applications**).
         Requests are filed under it and validated against its own form, if it has one.
       - locale: The language your app shows, when it chooses one itself
         (`"es"`, `"pt-BR"`…). `nil` uses the device's preferred language.
       - apiURL: The Faro API. Leave the default unless Pixel du Nord tells you otherwise.
     */
    public static func configure(
        key: String,
        app: String? = nil,
        locale: String? = nil,
        apiURL: URL = FaroConfiguration.defaultAPIURL
    ) {
        configure(FaroConfiguration(key: key, app: app, locale: locale, apiURL: apiURL))
    }

    /// Configures ``shared`` with a full ``FaroConfiguration``.
    public static func configure(_ configuration: FaroConfiguration) {
        let faro = Faro(configuration: configuration)
        current.withLock { $0 = faro }
    }

    /**
     The client set up by ``configure(key:app:locale:apiURL:)``.

     Before `configure` is called it still exists, but every call on it throws
     ``FaroError/notConfigured``.
     */
    public static var shared: Faro {
        current.withLock { $0 } ?? unconfigured
    }

    /// Whether ``configure(key:app:locale:apiURL:)`` has been called.
    public static var isConfigured: Bool {
        current.withLock { $0 != nil }
    }

    // MARK: - Identity

    private static let identity = Locked<FaroUser?>(nil)

    /**
     Tells Faro who is using the app, or `nil` when they sign out.

     The email and name prefill the help screen and are used when a request is
     sent without them. With a `signature` computed by **your server**, the
     person is also linked to their contact in Faro and their email counts as
     confirmed. The user is kept in memory only, never on disk.
     */
    public static func identify(_ user: FaroUser?) {
        identity.withLock { $0 = user }
    }

    /// The person passed to ``identify(_:)``, if any.
    public static var currentUser: FaroUser? {
        identity.withLock { $0 }
    }

    // MARK: - Breadcrumbs

    static let trail = BreadcrumbTrail()

    /**
     Records something the person just did ("Opened Settings", "Tapped Sync").

     Faro keeps the last ``FaroBreadcrumb/limit`` entries in memory, each cut to
     ``FaroBreadcrumb/maxLength`` characters, and sends them with the next request
     (as `context.breadcrumbs`, and the newest ones as the `trail` device fact),
     so the team sees what led to it. Keep them short and never
     put personal data, tokens or secrets in them.
     */
    public static func breadcrumb(_ message: String) {
        trail.add(message)
    }

    /// The breadcrumbs that would travel with a request sent now, oldest first.
    public static var breadcrumbs: [FaroBreadcrumb] {
        trail.all
    }

    /**
     Exactly the device facts a request sent now would carry: the automatic ones
     (``FaroDevice/automatic()``), the `trail` of the newest breadcrumbs, the
     `userId` of an identified but unsigned user, and your `extra` ones, up to
     Faro's 12. Handy to show people what travels with their request.
     */
    public static func deviceFacts(adding extra: [String: String] = [:], includesBreadcrumbs: Bool = true) -> [String: String] {
        let user = currentUser
        let signed = !(user?.signature ?? "").isEmpty
        return FaroDevice.compose(
            extra: extra,
            trail: includesBreadcrumbs ? BreadcrumbTrail.trail(breadcrumbs) : nil,
            userId: signed ? nil : user?.id
        )
    }

    /// Forgets every breadcrumb (for example when the person signs out).
    public static func clearBreadcrumbs() {
        trail.clear()
    }

    // MARK: - The form

    /**
     Fetches the request form defined in the Faro panel, resolved to a language.

     The latest definition is cached on disk: if Faro cannot be reached, the
     cached one is returned (with ``FaroForm/source`` set to `.cache`). Without
     a network and without a cache, it throws.

     - Parameter locale: The language to resolve the texts to. `nil` uses the
       configured locale, then the device's. If the form does not offer it, the
       form's primary language is used.
     */
    public func form(locale: String? = nil) async throws -> FaroForm {
        try requireConfigured()
        let language = FaroLocale.language(locale ?? configuration.locale)
        let request = URLRequest(url: Endpoints(configuration: configuration).config)
        do {
            let body = try await HTTP.json(request, transport: transport)
            guard let snapshot = FormSnapshot(configResponse: body) else { throw FaroError.invalidResponse }
            cache.save(snapshot)
            return snapshot.form(language: language, source: .network)
        } catch let error as FaroError where error.isNetwork || (error.status ?? 0) >= 500 {
            if let cached = cachedForm(locale: locale) { return cached }
            throw error
        }
    }

    /**
     The last form fetched by ``form(locale:)``, straight from the disk cache,
     or `nil` if there is none. Use it to draw your screen instantly while the
     fresh one loads.
     */
    public func cachedForm(locale: String? = nil) -> FaroForm? {
        guard configuration.isValid else { return nil }
        let language = FaroLocale.language(locale ?? configuration.locale)
        return cache.load()?.form(language: language, source: .cache)
    }

    // MARK: - Sending

    /**
     Starts the anti-spam check in the background: asks Faro for a puzzle and
     solves it (a fraction of a second).

     Call it when your help screen opens. Faro does not accept a solution until
     3 seconds after the puzzle was handed out, so preparing early means the
     request goes out the moment the person taps Send. Calling it again while a
     fresh proof is ready or being solved does nothing.
     */
    public func prepare() {
        guard configuration.isValid else { return }
        Task { await proofs.prepare() }
    }

    /**
     Files a request and returns its ticket.

     It waits for the proof of work (preparing one if ``prepare()`` was not
     called), waits whatever is left of Faro's 3 second minimum, and retries
     once with a fresh puzzle if Faro rejects the proof. After a validation
     error (a missing field, a bad email, too many requests) the same proof is
     kept for the next attempt.

     The device facts, the identified user (``identify(_:)``) and the
     breadcrumbs (``breadcrumb(_:)``) are added automatically.

     - Throws: ``FaroError``. Use ``FaroError/invalidForm(field:)`` and the
       other cases to show the problem next to the right field.
     */
    @discardableResult
    public func send(_ request: FaroRequest) async throws -> FaroTicket {
        try requireConfigured()
        guard request.attachments.count <= FaroAttachment.maxCount,
              request.attachments.allSatisfy({ $0.data.count <= FaroAttachment.maxBytes }) else {
            throw FaroError.invalidAttachment
        }
        let payload = RequestPayload(
            request: request,
            configuration: configuration,
            user: Faro.currentUser,
            breadcrumbs: request.includesBreadcrumbs ? Faro.breadcrumbs : [],
            device: Faro.deviceFacts(adding: request.device, includesBreadcrumbs: request.includesBreadcrumbs)
        )
        let endpoint = Endpoints(configuration: configuration).requests

        var proof = try await proofs.proof()
        for attempt in 0..<2 {
            try await proofs.wait(for: proof)
            do {
                let urlRequest = try payload.urlRequest(to: endpoint, proof: proof)
                let body = try await HTTP.json(urlRequest, transport: transport)
                guard let ticket = FaroTicket(response: body) else { throw FaroError.invalidResponse }
                // A proof is spent once a request gets in: have the next one ready.
                await proofs.discard(proof)
                await proofs.prepare()
                return ticket
            } catch let error as FaroError {
                if case .spamCheck = error, attempt == 0 {
                    await proofs.discard(proof)
                    proof = try await proofs.proof()
                    continue
                }
                if !error.leavesProofUnspent { await proofs.discard(proof) }
                throw error
            }
        }
        throw FaroError.spamCheck(reason: "retry")
    }

    private func requireConfigured() throws {
        guard configuration.isValid else { throw FaroError.notConfigured }
    }
}
