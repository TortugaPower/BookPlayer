//
//  HardcoverOAuthTests.swift
//  BookPlayerTests
//
//  Created by Pedro Iniguez on 10/31/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

/// The authorize request and redirect checks follow the vectors in Hardcover's SDK
/// (`shared/conformance/oauth.json`); the session's refresh rules follow its `shared/auth.json`
class HardcoverOAuthTests: XCTestCase {
  // MARK: - PKCE and the authorize URL

  func testCodeChallengeMatchesRFC7636() {
    XCTAssertEqual(
      HardcoverOAuth.codeChallenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"),
      "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
    )
  }

  func testBase64URLHasNoPaddingOrUnsafeCharacters() {
    XCTAssertEqual(HardcoverOAuth.base64URL(Data()), "")
    XCTAssertEqual(HardcoverOAuth.base64URL(Data([0x00])), "AA")
    XCTAssertEqual(HardcoverOAuth.base64URL(Data([0xff])), "_w")
    XCTAssertEqual(HardcoverOAuth.base64URL(Data([0xfb, 0xff])), "-_8")
  }

  func testAuthorizationURLCarriesPKCEAndState() throws {
    let attempt = HardcoverOAuth.makeAuthorization(randomBytes: { [UInt8](repeating: 0, count: $0) })

    XCTAssertEqual(attempt.codeVerifier, String(repeating: "A", count: 43))
    XCTAssertEqual(attempt.state, String(repeating: "A", count: 22))

    let components = try XCTUnwrap(URLComponents(url: attempt.url, resolvingAgainstBaseURL: false))
    XCTAssertEqual(components.scheme, "https")
    XCTAssertEqual(components.host, "hardcover.app")
    XCTAssertEqual(components.path, "/oauth2/authorize")

    let params = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    XCTAssertEqual(params["response_type"], "code")
    XCTAssertEqual(params["client_id"], HardcoverOAuth.clientId)
    XCTAssertEqual(params["redirect_uri"], "bookplayer://hardcover/callback")
    XCTAssertEqual(params["scope"], "read:catalog read:library write:library read:me")
    XCTAssertEqual(params["state"], attempt.state)
    XCTAssertEqual(params["code_challenge"], "DwBzhbb51LfusnSGBa_hqYSgo7-j8BTQnip4TOnlzRo")
    XCTAssertEqual(params["code_challenge_method"], "S256")
  }

  func testEachAttemptGetsItsOwnVerifierAndState() {
    let first = HardcoverOAuth.makeAuthorization()
    let second = HardcoverOAuth.makeAuthorization()

    XCTAssertNotEqual(first.codeVerifier, second.codeVerifier)
    XCTAssertNotEqual(first.state, second.state)
    XCTAssertEqual(first.codeVerifier.count, 43)
  }

  // MARK: - Redirect

  private let attempt = HardcoverAuthorizationAttempt(
    url: URL(string: "https://hardcover.app/oauth2/authorize")!,
    state: "S1",
    codeVerifier: "verifier"
  )

  private func code(from redirect: String) throws -> String {
    try HardcoverOAuth.authorizationCode(from: URL(string: redirect)!, for: attempt)
  }

  func testRedirectGivesItsCode() throws {
    XCTAssertEqual(
      try code(from: "bookplayer://hardcover/callback?code=hc_ac_abc&state=S1&iss=https%3A%2F%2Fapi.hardcover.app"),
      "hc_ac_abc"
    )
  }

  func testRedirectWithoutIssuerOrWithAnEmptyOneIsAccepted() throws {
    XCTAssertEqual(try code(from: "bookplayer://hardcover/callback?code=hc_ac_abc&state=S1"), "hc_ac_abc")
    XCTAssertEqual(try code(from: "bookplayer://hardcover/callback?code=hc_ac_abc&state=S1&iss="), "hc_ac_abc")
  }

  func testRedirectFromAnotherAttemptIsRefused() {
    XCTAssertThrowsError(try code(from: "bookplayer://hardcover/callback?code=hc_ac_abc&state=S2")) {
      XCTAssertEqual($0 as? HardcoverOAuthError, .stateMismatch)
    }
    XCTAssertThrowsError(try code(from: "bookplayer://hardcover/callback?code=hc_ac_abc")) {
      XCTAssertEqual($0 as? HardcoverOAuthError, .stateMismatch)
    }
  }

  func testRedirectFromAnotherIssuerIsRefused() {
    XCTAssertThrowsError(
      try code(from: "bookplayer://hardcover/callback?code=hc_ac_abc&state=S1&iss=https%3A%2F%2Fevil.example")
    ) {
      XCTAssertEqual($0 as? HardcoverOAuthError, .issuerMismatch)
    }
  }

  func testDeclinedSignInReportsTheServerError() {
    XCTAssertThrowsError(try code(from: "bookplayer://hardcover/callback?error=access_denied&state=S1")) {
      XCTAssertEqual($0 as? HardcoverOAuthError, .server(code: "access_denied", description: nil))
    }
  }

  func testAnErrorWithTheWrongStateIsAStateMismatch() {
    XCTAssertThrowsError(try code(from: "bookplayer://hardcover/callback?error=access_denied&state=S2")) {
      XCTAssertEqual($0 as? HardcoverOAuthError, .stateMismatch)
    }
  }

  func testRedirectWithoutACodeIsRefused() {
    XCTAssertThrowsError(try code(from: "bookplayer://hardcover/callback?state=S1")) {
      XCTAssertEqual($0 as? HardcoverOAuthError, .missingCode)
    }
  }

  // MARK: - Token responses

  func testTokenResponseTimesItsExpiryFromArrival() throws {
    let receivedAt = Date(timeIntervalSince1970: 1_800_000_000)
    let tokens = try HardcoverTokenSet(
      response: [
        "access_token": "hc_at_a",
        "token_type": "Bearer",
        "expires_in": 604800,
        "scope": "read:library",
        "refresh_token": "hc_rt_a",
      ],
      receivedAt: receivedAt
    )

    XCTAssertEqual(tokens.accessToken, "hc_at_a")
    XCTAssertEqual(tokens.refreshToken, "hc_rt_a")
    XCTAssertEqual(tokens.scope, "read:library")
    XCTAssertEqual(tokens.expiresAt, receivedAt.addingTimeInterval(604800))
  }

  func testTokenResponseWithoutAnAccessTokenIsRefused() {
    XCTAssertThrowsError(try HardcoverTokenSet(response: ["refresh_token": "hc_rt_a"], receivedAt: Date())) {
      XCTAssertEqual($0 as? HardcoverOAuthError, .invalidResponse)
    }
  }

  /// A sign-in from before `read:library` was asked for keeps its old scopes through refreshes
  func testOlderSignInIsMissingTheScopesAddedSince() {
    let older = HardcoverTokenSet(
      accessToken: "hc_at_a",
      refreshToken: nil,
      scope: "read:catalog write:library read:me",
      expiresAt: nil
    )
    XCTAssertEqual(older.missingScopes, ["read:library"])

    var current = older
    current.scope = HardcoverOAuth.scopes.joined(separator: " ")
    XCTAssertTrue(current.missingScopes.isEmpty)

    /// No `scope` in the answer means what was asked was granted
    current.scope = ""
    XCTAssertTrue(current.missingScopes.isEmpty)
  }

  func testFormEncodingEscapesReservedCharacters() {
    XCTAssertEqual(
      HardcoverOAuth.formEncode(["redirect_uri": "bookplayer://hardcover/callback", "code": "a+b c"]),
      "code=a%2Bb%20c&redirect_uri=bookplayer%3A%2F%2Fhardcover%2Fcallback"
    )
  }

  // MARK: - Session

  private let now = Date(timeIntervalSince1970: 1_800_000_000)

  private func storedTokens(expiresIn: TimeInterval, refreshToken: String? = "hc_rt_old") -> HardcoverTokenSet {
    HardcoverTokenSet(
      accessToken: "hc_at_old",
      refreshToken: refreshToken,
      scope: "read:catalog read:library write:library read:me",
      expiresAt: now.addingTimeInterval(expiresIn)
    )
  }

  private func makeSession(
    keychain: KeychainServiceMock,
    server: TokenServerStub
  ) -> HardcoverOAuthSession {
    let now = self.now
    return HardcoverOAuthSession(
      keychain: keychain,
      send: { try await server.handle($0) },
      now: { now }
    )
  }

  func testNotSignedInHasNoToken() async throws {
    let session = makeSession(keychain: KeychainServiceMock(), server: TokenServerStub())

    let token = try await session.accessToken()

    XCTAssertNil(token)
    XCTAssertFalse(session.isSignedIn)
  }

  func testATokenWithTimeLeftIsUsedAsIs() async throws {
    let keychain = KeychainServiceMock()
    try keychain.set(storedTokens(expiresIn: 3600), key: .hardcoverSession)
    let server = TokenServerStub()
    let session = makeSession(keychain: keychain, server: server)

    let token = try await session.accessToken()

    XCTAssertEqual(token, "hc_at_old")
    let requests = await server.requests
    XCTAssertTrue(requests.isEmpty)
  }

  func testATokenAboutToExpireIsRefreshedAndTheNewPairStored() async throws {
    let keychain = KeychainServiceMock()
    try keychain.set(storedTokens(expiresIn: 30), key: .hardcoverSession)
    let server = TokenServerStub()
    let session = makeSession(keychain: keychain, server: server)

    let token = try await session.accessToken()

    XCTAssertEqual(token, "hc_at_new1")
    let stored: HardcoverTokenSet? = try keychain.get(.hardcoverSession)
    XCTAssertEqual(stored?.refreshToken, "hc_rt_new1")

    let requests = await server.requests
    XCTAssertEqual(requests.count, 1)
    XCTAssertEqual(requests.first?["grant_type"], "refresh_token")
    XCTAssertEqual(requests.first?["refresh_token"], "hc_rt_old")
    XCTAssertEqual(requests.first?["client_id"], HardcoverOAuth.clientId)
  }

  func testConcurrentCallersShareOneRefresh() async throws {
    let keychain = KeychainServiceMock()
    try keychain.set(storedTokens(expiresIn: 30), key: .hardcoverSession)
    let server = TokenServerStub(delay: 0.05)
    let session = makeSession(keychain: keychain, server: server)

    async let first = session.accessToken()
    async let second = session.accessToken()
    async let third = session.accessToken()
    let tokens = try await [first, second, third]

    XCTAssertEqual(tokens, ["hc_at_new1", "hc_at_new1", "hc_at_new1"])
    let requests = await server.requests
    XCTAssertEqual(requests.count, 1, "A spent refresh token sent again revokes the whole sign-in")
  }

  func testARejectedTokenIsRefreshedOnce() async throws {
    let keychain = KeychainServiceMock()
    try keychain.set(storedTokens(expiresIn: 3600), key: .hardcoverSession)
    let server = TokenServerStub()
    let session = makeSession(keychain: keychain, server: server)

    let refreshed = try await session.accessToken(replacing: "hc_at_old")
    /// A second request refused with the same old token finds it already replaced
    let again = try await session.accessToken(replacing: "hc_at_old")

    XCTAssertEqual(refreshed, "hc_at_new1")
    XCTAssertEqual(again, "hc_at_new1")
    let requests = await server.requests
    XCTAssertEqual(requests.count, 1)
  }

  func testARefusedRefreshTokenSignsOut() async throws {
    let keychain = KeychainServiceMock()
    try keychain.set(storedTokens(expiresIn: 30), key: .hardcoverSession)
    let server = TokenServerStub(answer: .invalidGrant)
    let session = makeSession(keychain: keychain, server: server)

    do {
      _ = try await session.accessToken()
      XCTFail("Expected invalid_grant")
    } catch {
      XCTAssertEqual(error as? HardcoverOAuthError, .invalidGrant)
    }

    XCTAssertFalse(session.isSignedIn)
  }

  func testAFailedRefreshKeepsAnUnexpiredTokenAndWaitsBeforeTryingAgain() async throws {
    let keychain = KeychainServiceMock()
    try keychain.set(storedTokens(expiresIn: 30), key: .hardcoverSession)
    let server = TokenServerStub(answer: .offline)
    let session = makeSession(keychain: keychain, server: server)

    let first = try await session.accessToken()
    let second = try await session.accessToken()

    XCTAssertEqual(first, "hc_at_old")
    XCTAssertEqual(second, "hc_at_old")
    XCTAssertTrue(session.isSignedIn)
    let requests = await server.requests
    XCTAssertEqual(requests.count, 1)
  }

  func testAFailedRefreshOfAnExpiredTokenThrows() async throws {
    let keychain = KeychainServiceMock()
    try keychain.set(storedTokens(expiresIn: -10), key: .hardcoverSession)
    let server = TokenServerStub(answer: .offline)
    let session = makeSession(keychain: keychain, server: server)

    do {
      _ = try await session.accessToken()
      XCTFail("Expected the network error")
    } catch {
      XCTAssertTrue(error is URLError)
    }

    XCTAssertTrue(session.isSignedIn, "Only invalid_grant ends the sign-in")
  }

  func testSigningInExchangesTheCodeWithItsVerifier() async throws {
    let keychain = KeychainServiceMock()
    let server = TokenServerStub()
    let session = makeSession(keychain: keychain, server: server)

    try await session.signIn(code: "hc_ac_abc", codeVerifier: "verifier")

    XCTAssertTrue(session.isSignedIn)
    let requests = await server.requests
    XCTAssertEqual(requests.first?["grant_type"], "authorization_code")
    XCTAssertEqual(requests.first?["code"], "hc_ac_abc")
    XCTAssertEqual(requests.first?["code_verifier"], "verifier")
    XCTAssertEqual(requests.first?["redirect_uri"], "bookplayer://hardcover/callback")
  }

  func testSigningOutForgetsTheTokensAndRevokesThem() async throws {
    let keychain = KeychainServiceMock()
    try keychain.set(storedTokens(expiresIn: 3600), key: .hardcoverSession)
    let server = TokenServerStub()
    let session = makeSession(keychain: keychain, server: server)

    await session.signOut()

    XCTAssertFalse(session.isSignedIn)
    let urls = await server.urls
    XCTAssertEqual(urls, [HardcoverOAuth.revokeURL])
    let requests = await server.requests
    XCTAssertEqual(requests.first?["token"], "hc_rt_old")
  }
}

/// Answers Hardcover's token and revoke endpoints, recording each form it receives
private actor TokenServerStub {
  enum Answer {
    case tokens
    case invalidGrant
    case offline
  }

  private let answer: Answer
  private let delay: TimeInterval
  private(set) var requests: [[String: String]] = []
  private(set) var urls: [URL] = []

  init(answer: Answer = .tokens, delay: TimeInterval = 0) {
    self.answer = answer
    self.delay = delay
  }

  func handle(_ request: URLRequest) async throws -> (Data, URLResponse) {
    let url = request.url!
    urls.append(url)
    requests.append(Self.form(request.httpBody ?? Data()))
    let issued = requests.count

    if delay > 0 {
      try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    if url == HardcoverOAuth.revokeURL {
      return (Data(), Self.response(url, status: 200))
    }

    switch answer {
    case .offline:
      throw URLError(.notConnectedToInternet)
    case .invalidGrant:
      let body = try JSONSerialization.data(withJSONObject: ["error": "invalid_grant"])
      return (body, Self.response(url, status: 400))
    case .tokens:
      let body = try JSONSerialization.data(withJSONObject: [
        "access_token": "hc_at_new\(issued)",
        "refresh_token": "hc_rt_new\(issued)",
        "token_type": "Bearer",
        "expires_in": 604800,
        "scope": "read:catalog read:library write:library read:me",
      ])
      return (body, Self.response(url, status: 200))
    }
  }

  private static func response(_ url: URL, status: Int) -> URLResponse {
    HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
  }

  private static func form(_ body: Data) -> [String: String] {
    var components = URLComponents()
    components.percentEncodedQuery = String(data: body, encoding: .utf8)
    return Dictionary(
      (components.queryItems ?? []).map { ($0.name, $0.value ?? "") },
      uniquingKeysWith: { first, _ in first }
    )
  }
}
