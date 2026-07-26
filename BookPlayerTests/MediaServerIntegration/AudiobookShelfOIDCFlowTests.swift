//
//  AudiobookShelfOIDCFlowTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

@MainActor
final class AudiobookShelfOIDCFlowTests: XCTestCase {
  private var http: IntegrationHTTPClientStub!
  private var webAuth: WebAuthenticatingStub!
  private var sut: AudiobookShelfOIDCFlow!

  private let secureURL = URL(string: "https://abs.example.com")!

  override func setUp() {
    super.setUp()
    http = IntegrationHTTPClientStub()
    webAuth = WebAuthenticatingStub()
    sut = AudiobookShelfOIDCFlow(http: http, webAuth: webAuth)
  }

  override func tearDown() {
    http = nil
    webAuth = nil
    sut = nil
    super.tearDown()
  }

  // MARK: - Callback parsing (no client needed)

  func testAuthorizationCodeAcceptsAMatchingState() throws {
    let callback = URL(string: "audiobookshelf://oauth?code=the-code&state=expected")!

    let code = try AudiobookShelfOIDCFlow.authorizationCode(from: callback, expectedState: "expected")

    XCTAssertEqual(code, "the-code")
  }

  func testAuthorizationCodeRejectsAMismatchedState() {
    let callback = URL(string: "audiobookshelf://oauth?code=the-code&state=attacker")!

    XCTAssertThrowsError(
      try AudiobookShelfOIDCFlow.authorizationCode(from: callback, expectedState: "expected")
    )
  }

  func testAuthorizationCodeRejectsAMissingState() {
    let callback = URL(string: "audiobookshelf://oauth?code=the-code")!

    XCTAssertThrowsError(
      try AudiobookShelfOIDCFlow.authorizationCode(from: callback, expectedState: "expected")
    )
  }

  func testAuthorizationCodeSurfacesAProviderErrorBeforeCheckingState() throws {
    // On an identity-provider denial, AudiobookShelf still redirects with a *valid* state and the
    // literal string `code=undefined`. A state-first check would sail past that and exchange nonsense,
    // so the error has to win.
    let callback = URL(
      string: "audiobookshelf://oauth?error=access_denied&error_description=User%20declined&state=expected&code=undefined"
    )!

    XCTAssertThrowsError(
      try AudiobookShelfOIDCFlow.authorizationCode(from: callback, expectedState: "expected")
    ) { error in
      guard case .serverMessage(_, let message) = error as? IntegrationError else {
        return XCTFail("expected a serverMessage, got \(error)")
      }
      XCTAssertEqual(message, "User declined")
    }
  }

  func testAuthorizationCodeRejectsTheUndefinedSentinelWithAnActionableError() {
    // AudiobookShelf's mobile-redirect interpolates a missing `code` as the literal "undefined" and
    // discards the provider's own error, so this sentinel is the only signal that the identity provider
    // refused. The message has to name the URI the provider must allow, or the user is stuck.
    let callback = URL(string: "audiobookshelf://oauth?code=undefined&state=expected")!

    XCTAssertThrowsError(
      try AudiobookShelfOIDCFlow.authorizationCode(
        from: callback,
        expectedState: "expected",
        providerCallbackURL: "https://abs.example.com/auth/openid/mobile-redirect"
      )
    ) { error in
      XCTAssertEqual(
        error as? IntegrationError,
        .ssoNoAuthorizationCode(providerCallbackURL: "https://abs.example.com/auth/openid/mobile-redirect")
      )
    }
  }

  func testProviderCallbackURLIsTheMobileRedirectRoute() {
    // Not our custom scheme: AudiobookShelf points the provider at its own route and only then bounces
    // to `audiobookshelf://oauth`.
    XCTAssertEqual(
      AudiobookShelfOIDCFlow.providerCallbackURL(for: URL(string: "https://abs.example.com:5006")!),
      "https://abs.example.com:5006/auth/openid/mobile-redirect"
    )
  }

  // MARK: - Transport

  func testRunRefusesPlaintextBeforeMakingAnyRequest() async {
    do {
      _ = try await sut.run(
        baseURL: URL(string: "http://abs.example.com")!,
        serverName: "Test",
        customHeaders: [:],
        prefersEphemeralSession: false
      )
      XCTFail("expected the flow to refuse http")
    } catch {
      XCTAssertEqual(error as? IntegrationError, .insecureTransport)
    }
    // The code, verifier and token all traverse the redirect chain, so nothing should have gone out.
    XCTAssertTrue(http.redirectRequests.isEmpty)
    XCTAssertTrue(webAuth.receivedURLs.isEmpty)
  }

  // MARK: - Happy path

  func testRunFetchesTheAuthorizeURLItselfThenExchangesTheCode() async throws {
    webAuth.outcome = .code("abc")
    http.dataResult = .success(
      (Self.userPayload(token: "api-token", id: "user-9", username: "hana"), 200)
    )

    let credentials = try await sut.run(
      baseURL: secureURL,
      serverName: "Test",
      customHeaders: ["CF-Access-Client-Id": "cf"],
      prefersEphemeralSession: true
    )

    XCTAssertEqual(credentials.apiToken, "api-token")
    XCTAssertEqual(credentials.userID, "user-9")
    XCTAssertEqual(credentials.userName, "hana")

    // Step 1 must be made by the app, not the browser: that is what puts ABS's session cookie in our
    // own cookie jar so the step-3 exchange is accepted.
    let authorizeRequest = try XCTUnwrap(http.redirectRequests.first)
    let authorizeURL = try XCTUnwrap(authorizeRequest.url)
    XCTAssertEqual(authorizeURL.path, "/auth/openid")
    let query = try XCTUnwrap(URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)?.queryItems)
    XCTAssertEqual(query.first { $0.name == "redirect_uri" }?.value, "audiobookshelf://oauth")
    XCTAssertEqual(query.first { $0.name == "code_challenge_method" }?.value, "S256")
    XCTAssertNotNil(query.first { $0.name == "code_challenge" }?.value)
    // ABS builds the provider request from its own server settings and ignores a client-sent id.
    XCTAssertNil(query.first { $0.name == "client_id" })
    // Custom headers belong on the calls we make ourselves.
    XCTAssertEqual(authorizeRequest.value(forHTTPHeaderField: "CF-Access-Client-Id"), "cf")

    // Only the identity-provider URL may reach the browser.
    let browserURL = try XCTUnwrap(webAuth.receivedURLs.first)
    XCTAssertEqual(webAuth.receivedURLs.count, 1)
    XCTAssertEqual(browserURL.host, "idp.example.com")
    XCTAssertEqual(browserURL.path, "/authorize")
    XCTAssertEqual(webAuth.receivedSchemes, ["audiobookshelf"])
    XCTAssertEqual(webAuth.receivedEphemeralFlags, [true])

    // Step 3 carries the verifier that matches the challenge from step 1.
    let exchangeURL = try XCTUnwrap(http.dataRequests.first?.url)
    XCTAssertEqual(exchangeURL.path, "/auth/openid/callback")
    let exchangeQuery = try XCTUnwrap(
      URLComponents(url: exchangeURL, resolvingAgainstBaseURL: false)?.queryItems
    )
    let sentVerifier = try XCTUnwrap(exchangeQuery.first { $0.name == "code_verifier" }?.value)
    let sentChallenge = try XCTUnwrap(query.first { $0.name == "code_challenge" }?.value)
    XCTAssertEqual(PKCE(verifier: sentVerifier).challenge, sentChallenge)
    XCTAssertEqual(exchangeQuery.first { $0.name == "code" }?.value, "abc")
  }

  func testRunFallsBackToNameThenServerNameForTheLabel() async throws {
    webAuth.outcome = .code("abc")
    let json = #"{"user":{"token":"t","id":"u","name":"Display Name"}}"#
    http.dataResult = .success((Data(json.utf8), 200))

    let credentials = try await sut.run(
      baseURL: secureURL, serverName: "Fallback", customHeaders: [:], prefersEphemeralSession: false
    )

    XCTAssertEqual(credentials.userName, "Display Name")
  }

  // MARK: - Failure paths

  func testRunPropagatesAServerRefusalToStartTheHandshake() async {
    // e.g. an admin removed `audiobookshelf://oauth` from the mobile redirect whitelist.
    http.redirectFailure = IntegrationError.serverMessage(code: 400, message: "Invalid redirect_uri")

    do {
      _ = try await sut.run(
        baseURL: secureURL, serverName: "Test", customHeaders: [:], prefersEphemeralSession: false
      )
      XCTFail("expected the refusal to propagate")
    } catch {
      guard case .serverMessage(let code, let message) = error as? IntegrationError else {
        return XCTFail("expected a serverMessage, got \(error)")
      }
      XCTAssertEqual(code, 400)
      XCTAssertEqual(message, "Invalid redirect_uri")
    }
    XCTAssertTrue(webAuth.receivedURLs.isEmpty, "must not open a browser after a failed start")
  }

  func testRunPropagatesUserCancellation() async {
    webAuth.outcome = .failure(CancellationError())

    do {
      _ = try await sut.run(
        baseURL: secureURL, serverName: "Test", customHeaders: [:], prefersEphemeralSession: false
      )
      XCTFail("expected cancellation to propagate")
    } catch {
      // The host view swallows exactly this, so it must not arrive as some other error type.
      XCTAssertTrue(error is CancellationError)
    }
    XCTAssertTrue(http.dataRequests.isEmpty, "a cancelled handshake must not exchange anything")
  }

  func testRunSurfacesTheServerMessageOnA401RatherThanPromptingReauth() async {
    webAuth.outcome = .code("abc")
    // AudiobookShelf answers `Unauthorized` when it won't map a provider identity to one of its users
    // (no match with auto-register off, a missing group claim, or a deactivated account).
    http.dataResult = .success((Data("Unauthorized".utf8), 401))

    do {
      _ = try await sut.run(
        baseURL: secureURL, serverName: "Test", customHeaders: [:], prefersEphemeralSession: false
      )
      XCTFail("expected a 401 to throw")
    } catch {
      // Must NOT be `userAuthenticationRequired`: the provider already authenticated the user, so a
      // re-auth prompt is something they cannot act on.
      XCTAssertNil(error as? URLError)
      XCTAssertEqual(error as? IntegrationError, .serverMessage(code: 401, message: "Unauthorized"))
    }
  }

  func testRunSurfacesTheServerMessageOnAFailedExchange() async {
    webAuth.outcome = .code("abc")
    // The exact failure the old implementation produced on every server, now diagnosable.
    http.dataResult = .success((Data("No session".utf8), 400))

    do {
      _ = try await sut.run(
        baseURL: secureURL, serverName: "Test", customHeaders: [:], prefersEphemeralSession: false
      )
      XCTFail("expected the exchange to throw")
    } catch {
      guard case .serverMessage(_, let message) = error as? IntegrationError else {
        return XCTFail("expected a serverMessage, got \(error)")
      }
      XCTAssertEqual(message, "No session")
    }
  }

  func testRunRejectsAResponseMissingTheToken() async {
    webAuth.outcome = .code("abc")
    http.dataResult = .success((Data(#"{"user":{"id":"u"}}"#.utf8), 200))

    do {
      _ = try await sut.run(
        baseURL: secureURL, serverName: "Test", customHeaders: [:], prefersEphemeralSession: false
      )
      XCTFail("expected a tokenless payload to throw")
    } catch {
      XCTAssertEqual(error as? IntegrationError, .unexpectedResponse(code: nil))
    }
  }

  func testRunRejectsMalformedJSON() async {
    webAuth.outcome = .code("abc")
    http.dataResult = .success((Data("not json".utf8), 200))

    do {
      _ = try await sut.run(
        baseURL: secureURL, serverName: "Test", customHeaders: [:], prefersEphemeralSession: false
      )
      XCTFail("expected malformed JSON to throw")
    } catch {
      XCTAssertEqual(error as? IntegrationError, .unexpectedResponse(code: nil))
    }
  }

  private static func userPayload(token: String, id: String, username: String) -> Data {
    Data(#"{"user":{"token":"\#(token)","id":"\#(id)","username":"\#(username)"}}"#.utf8)
  }
}

// MARK: - Stubs

/// Propagates `state` the way AudiobookShelf does — its 302 `Location` carries the state we sent — so
/// the tests exercise the real round-trip instead of a hardcoded value the flow would rightly reject.
private final class IntegrationHTTPClientStub: IntegrationHTTPClient {
  /// When set, the authorize request fails with this instead of answering.
  var redirectFailure: Error?
  var identityProviderURL = "https://idp.example.com/authorize"
  var dataResult: Result<(Data, Int), Error> = .failure(IntegrationError.unexpectedResponse(code: nil))

  private(set) var redirectRequests: [URLRequest] = []
  private(set) var dataRequests: [URLRequest] = []

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    dataRequests.append(request)
    let (data, status) = try dataResult.get()
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: status,
      httpVersion: nil,
      headerFields: nil
    )!
    return (data, response)
  }

  func redirectLocation(for request: URLRequest) async throws -> URL {
    redirectRequests.append(request)
    if let redirectFailure {
      throw redirectFailure
    }
    var components = URLComponents(string: identityProviderURL)!
    components.queryItems = [
      URLQueryItem(name: "state", value: queryValue("state", in: request.url))
    ]
    return components.url!
  }
}

@MainActor
private final class WebAuthenticatingStub: WebAuthenticating {
  enum Outcome {
    /// Succeed, echoing back the state found in the authorize URL (what a real provider does).
    case code(String)
    /// Return a callback verbatim, for malformed/hostile shapes.
    case rawCallback(String)
    case failure(Error)
  }

  var outcome: Outcome = .failure(CancellationError())

  private(set) var receivedURLs: [URL] = []
  private(set) var receivedSchemes: [String] = []
  private(set) var receivedEphemeralFlags: [Bool] = []

  func authenticate(
    url: URL,
    callbackScheme: String,
    prefersEphemeralSession: Bool
  ) async throws -> URL {
    receivedURLs.append(url)
    receivedSchemes.append(callbackScheme)
    receivedEphemeralFlags.append(prefersEphemeralSession)

    switch outcome {
    case .failure(let error):
      throw error
    case .rawCallback(let string):
      return URL(string: string)!
    case .code(let code):
      var components = URLComponents(string: "audiobookshelf://oauth")!
      components.queryItems = [
        URLQueryItem(name: "code", value: code),
        URLQueryItem(name: "state", value: queryValue("state", in: url)),
      ]
      return components.url!
    }
  }
}

private func queryValue(_ name: String, in url: URL?) -> String? {
  guard let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
    return nil
  }
  return components.queryItems?.first { $0.name == name }?.value
}
