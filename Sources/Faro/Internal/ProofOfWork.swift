import CryptoKit
import Foundation

/**
 A solved puzzle (Faro's proof of work, the anti-spam without a captcha), good
 for ONE request that gets in.

 `receivedAt` uses the monotonic clock (`systemUptime`) and marks when the
 puzzle ARRIVED, which is never before Faro handed it out: waiting
 ``ProofStore/serverMinimumWait`` from there always clears Faro's 3 s rule,
 whatever the phone's clock says.
 */
struct FaroProof: Sendable, Hashable {
    let salt: String
    let number: Int
    let challenge: String
    let signature: String
    let receivedAt: TimeInterval

    var age: TimeInterval { ProcessInfo.processInfo.systemUptime - receivedAt }

    var payload: [String: Any] {
        ["salt": salt, "number": number, "challenge": challenge, "signature": signature]
    }
}

enum ProofOfWork {
    /// Asks Faro for a puzzle (`GET /widget/challenge`) and solves it off the caller's thread.
    static func fetch(from endpoints: Endpoints, transport: any FaroTransport) async throws -> FaroProof {
        let puzzle = try await HTTP.json(URLRequest(url: endpoints.challenge), transport: transport)
        let receivedAt = ProcessInfo.processInfo.systemUptime
        guard let salt = puzzle["salt"] as? String,
              let challenge = puzzle["challenge"] as? String,
              let signature = puzzle["signature"] as? String else { throw FaroError.invalidResponse }
        let max = (puzzle["maxnumber"] as? NSNumber)?.intValue ?? 50_000
        let number = try await Task.detached(priority: .userInitiated) {
            try solve(salt: salt, challenge: challenge, max: max)
        }.value
        guard let number else { throw FaroError.spamCheck(reason: "unsolvable") }
        return FaroProof(salt: salt, number: number, challenge: challenge, signature: signature, receivedAt: receivedAt)
    }

    /**
     The `n` in `0...max` such that the hex SHA-256 of `salt` followed by `n` in
     decimal equals `challenge`, or `nil` if there is none. About 25,000 hashes
     on average: well under a second on any phone.
     */
    static func solve(salt: String, challenge: String, max: Int) throws -> Int? {
        guard let target = bytes(hex: challenge), target.count == SHA256.byteCount, max >= 0 else { return nil }
        var prefix = SHA256()
        prefix.update(data: Data(salt.utf8))
        for n in 0...max {
            // Every 2,000 tries, give up if nobody is waiting any more.
            if n % 2_000 == 0 { try Task.checkCancellation() }
            var hash = prefix
            hash.update(data: Array(String(n).utf8))
            if hash.finalize().elementsEqual(target) { return n }
        }
        return nil
    }

    static func bytes(hex: String) -> [UInt8]? {
        let characters = Array(hex.utf8)
        guard characters.count % 2 == 0 else { return nil }
        var result: [UInt8] = []
        result.reserveCapacity(characters.count / 2)
        var index = 0
        while index < characters.count {
            guard let high = nibble(characters[index]), let low = nibble(characters[index + 1]) else { return nil }
            result.append(high << 4 | low)
            index += 2
        }
        return result
    }

    private static func nibble(_ c: UInt8) -> UInt8? {
        switch c {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): return c - UInt8(ascii: "0")
        case UInt8(ascii: "a")...UInt8(ascii: "f"): return c - UInt8(ascii: "a") + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"): return c - UInt8(ascii: "A") + 10
        default: return nil
        }
    }
}

/**
 Keeps the proof for the next request.

 - ``prepare()`` starts solving one in the background (when the screen opens).
 - ``proof()`` hands out the ready one, or waits for / starts one.
 - The proof stays after a validation error (Faro checks it last, so it was
   not spent) and is dropped with ``discard(_:)`` after a success or a
   rejection.
 */
actor ProofStore {
    /// Faro requires 3 s between handing out a puzzle and accepting it; 200 ms of margin.
    static let serverMinimumWait: TimeInterval = 3.2
    /// Faro honors a puzzle for 20 minutes; renew at 15 to stay clear of the limit.
    static let lifetime: TimeInterval = 15 * 60

    private let fetch: @Sendable () async throws -> FaroProof
    private let minimumWait: TimeInterval
    private var ready: FaroProof?
    private var solving: Task<FaroProof, Error>?

    init(minimumWait: TimeInterval, fetch: @escaping @Sendable () async throws -> FaroProof) {
        self.minimumWait = minimumWait
        self.fetch = fetch
    }

    private func isFresh(_ proof: FaroProof) -> Bool { proof.age < Self.lifetime }

    /// Starts solving a proof unless a fresh one is ready or on its way.
    func prepare() {
        if let ready, isFresh(ready) { return }
        if solving != nil { return }
        start()
    }

    /// The proof to use now: the ready one, the one being solved, or a new one.
    func proof() async throws -> FaroProof {
        if let ready, isFresh(ready) { return ready }
        if let pending = solving {
            do {
                let proof = try await settle(pending)
                if isFresh(proof) { return proof }
                discard(proof)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // It was started earlier (maybe offline): one fresh attempt now.
            }
        }
        return try await settle(start())
    }

    /// Waits whatever is left of Faro's minimum time for `proof`.
    func wait(for proof: FaroProof) async throws {
        let remaining = minimumWait - proof.age
        if remaining > 0 { try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000)) }
    }

    /// Forgets `proof` (spent or rejected).
    func discard(_ proof: FaroProof) {
        if ready?.challenge == proof.challenge { ready = nil }
    }

    @discardableResult
    private func start() -> Task<FaroProof, Error> {
        ready = nil
        let fetch = self.fetch
        let task = Task { try await fetch() }
        solving = task
        return task
    }

    private func settle(_ task: Task<FaroProof, Error>) async throws -> FaroProof {
        do {
            let proof = try await task.value
            if solving == task {
                solving = nil
                ready = proof
            }
            return proof
        } catch {
            if solving == task { solving = nil }
            throw error
        }
    }
}
