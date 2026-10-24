import Foundation

/// How the SDK reaches the network. Tests swap it for a fake.
protocol FaroTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// The real transport: an ephemeral `URLSession` (no cookies, no disk cache).
struct URLSessionTransport: FaroTransport {
    let session: URLSession

    init(timeout: TimeInterval) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout * 3
        configuration.waitsForConnectivity = false
        configuration.httpAdditionalHeaders = ["X-Faro-SDK": "ios/\(Faro.version)"]
        session = URLSession(configuration: configuration)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

enum HTTP {
    /**
     Performs the call and returns the JSON body. Failures to reach Faro come out
     as ``FaroError/network(_:)``; Faro's error answers as the matching ``FaroError``.
     */
    static func json(_ request: URLRequest, transport: any FaroTransport) async throws -> [String: Any] {
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw FaroError.network((error as? URLError)?.localizedDescription ?? error.localizedDescription)
        }
        let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard (200...299).contains(response.statusCode) else {
            throw FaroError.from(
                status: response.statusCode,
                code: body?["errorCode"] as? String,
                message: body?["message"] as? String,
                field: body?["field"] as? String,
                reason: body?["reason"] as? String
            )
        }
        guard let body else { throw FaroError.invalidResponse }
        return body
    }
}
