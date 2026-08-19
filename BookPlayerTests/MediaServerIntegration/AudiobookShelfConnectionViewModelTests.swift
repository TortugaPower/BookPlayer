//
//  AudiobookShelfConnectionViewModelTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

/// Covers the two regressions found on device: custom headers being wiped after sign-in, and the
/// re-authentication path offering no way back in for an SSO-only connection.
@MainActor
final class AudiobookShelfConnectionViewModelTests: XCTestCase {
  private var keychain: KeychainServiceMock!
  private var defaults: UserDefaults!
  private var suiteName: String!
  private var http: OIDCHTTPStub!
  private var webAuth: OIDCWebAuthStub!
  private var service: AudiobookShelfConnectionService!

  private let serverURL = "https://abs.example.com"

  override func setUp() {
    super.setUp()
    keychain = KeychainServiceMock()
    suiteName = "ABSConnectionVMTests.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)
    http = OIDCHTTPStub()
    webAuth = OIDCWebAuthStub()
    service = AudiobookShelfConnectionService(
      keychainService: keychain,
      httpClient: http,
      webAuthenticator: webAuth,
      defaults: defaults
    )
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    keychain = nil
    defaults = nil
    http = nil
    webAuth = nil
    service = nil
    super.tearDown()
  }

  private func persistedHeaders() throws -> [String: String]? {
    let stored: [AudiobookShelfConnectionData]? = try keychain.get(.audiobookshelfConnection)
    return stored?.first?.customHeaders
  }

  // MARK: - Custom headers survive sign-in

  func testCustomHeadersSurviveSSOSignInAndASubsequentCommit() async throws {
    let viewModel = AudiobookShelfConnectionViewModel(connectionService: service, mode: .addServer)

    // The user types a header on the add-server form before authenticating.
    viewModel.form.serverUrl = serverURL
    viewModel.form.customHeaders = [
      CustomHeaderEntry(key: "CF-Access-Client-Id", value: "abc123")
    ]

    http.statusPayload = Data(#"{"authMethods":["local","openid"]}"#.utf8)
    http.pingPayload = Data(#"{"success":true}"#.utf8)
    try await viewModel.handleConnectAction()

    webAuth.code = "the-code"
    http.exchangePayload = Data(#"{"user":{"token":"t","id":"u1","username":"gianni"}}"#.utf8)
    try await viewModel.handleStartAlternativeSignIn()

    // Sign-in itself must persist them.
    XCTAssertEqual(try persistedHeaders(), ["CF-Access-Client-Id": "abc123"])

    // …and the form must still mirror them. The editable details section that once committed form
    // state over the saved connection is gone, but the form staying truthful still matters: the
    // re-auth flow prefills from it.
    XCTAssertEqual(
      viewModel.form.customHeadersDictionary(),
      ["CF-Access-Client-Id": "abc123"],
      "form headers were cleared after sign-in"
    )
  }

  /// The commit-on-close that once made this dangerous is gone — connection details is read-only —
  /// but the form still prefills from the saved connection, and re-auth depends on those headers
  /// arriving intact: a Cloudflare-Access server can't even be pinged without them.
  func testDetailsFormPrefillsTheSavedHeaders() throws {
    // Seed a saved connection that already has headers, as a relaunch would.
    try keychain.set(
      [
        AudiobookShelfConnectionData(
          id: "a",
          url: URL(string: serverURL)!,
          serverName: "Home",
          userID: "u1",
          userName: "gianni",
          apiToken: "token",
          customHeaders: ["CF-Access-Client-Id": "abc123"]
        )
      ],
      key: .audiobookshelfConnection
    )
    service.setup()

    let viewModel = AudiobookShelfConnectionViewModel(connectionService: service)

    XCTAssertEqual(
      viewModel.form.customHeadersDictionary(),
      ["CF-Access-Client-Id": "abc123"],
      "the details form must mirror the saved headers — re-auth prefills from it"
    )
    XCTAssertEqual(try persistedHeaders(), ["CF-Access-Client-Id": "abc123"])
  }

  // MARK: - Re-authentication

  func testPrepareReauthRestoresEnoughStateToSignInAgain() async throws {
    try keychain.set(
      [
        AudiobookShelfConnectionData(
          id: "a",
          url: URL(string: serverURL)!,
          serverName: "Home",
          userID: "u1",
          userName: "gianni",
          apiToken: "stale",
          customHeaders: ["CF-Access-Client-Id": "abc123"]
        )
      ],
      key: .audiobookshelfConnection
    )
    service.setup()

    let viewModel = AudiobookShelfConnectionViewModel(connectionService: service)
    viewModel.prepareReauth()

    // Must land on a step that actually offers a way back in — `nil` is the read-only details view,
    // which has no sign-in affordance at all for either password or SSO connections.
    XCTAssertEqual(viewModel.signInFlow, .enteringServerURL)
    // And the form has to carry the saved connection forward, headers included, so the re-validation
    // hits the same server with the same proxy credentials.
    XCTAssertEqual(viewModel.form.serverUrl, serverURL)
    XCTAssertEqual(viewModel.form.customHeadersDictionary(), ["CF-Access-Client-Id": "abc123"])
  }

  func testSSOBecomesAvailableAgainAfterReauthConnect() async throws {
    try keychain.set(
      [
        AudiobookShelfConnectionData(
          id: "a",
          url: URL(string: serverURL)!,
          serverName: "Home",
          userID: "u1",
          userName: "gianni",
          apiToken: "stale",
          customHeaders: [:]
        )
      ],
      key: .audiobookshelfConnection
    )
    service.setup()

    let viewModel = AudiobookShelfConnectionViewModel(connectionService: service)

    // Straight into the credentials step, SSO is not on offer: capabilities and the validated URL are
    // only established by Connect. An SSO-only user with no password would be stranded here.
    XCTAssertNil(viewModel.alternativeSignIn)

    viewModel.prepareReauth()
    http.statusPayload = Data(#"{"authMethods":["local","openid"]}"#.utf8)
    http.pingPayload = Data(#"{"success":true}"#.utf8)
    try await viewModel.handleConnectAction()

    XCTAssertEqual(viewModel.signInFlow, .enteringCredentials)
    XCTAssertEqual(
      viewModel.alternativeSignIn,
      .oidc(buttonText: nil),
      "SSO must be offered again when re-authenticating"
    )
  }

  func testSSOStaysHiddenOverPlaintextEvenWhenTheServerSupportsIt() async throws {
    let viewModel = AudiobookShelfConnectionViewModel(connectionService: service, mode: .addServer)
    viewModel.form.serverUrl = "http://abs.example.com"

    http.statusPayload = Data(#"{"authMethods":["local","openid"]}"#.utf8)
    http.pingPayload = Data(#"{"success":true}"#.utf8)
    try await viewModel.handleConnectAction()

    XCTAssertNil(
      viewModel.alternativeSignIn,
      "SSO over plaintext is simply not offered — the scheme control makes http visible and actionable"
    )
  }

  // MARK: - Re-auth against a moved server

  /// The sharp edge of keying connections on url+user: re-authenticating a server that moved host
  /// signs into an account no row matches, and without carrying the original connection's id the old
  /// row would survive as an expired orphan next to the new one.
  func testReauthWithAnEditedURLUpdatesTheRowInsteadOfForking() async throws {
    try keychain.set(
      [
        AudiobookShelfConnectionData(
          id: "a",
          url: URL(string: serverURL)!,
          serverName: "Home",
          userID: "u1",
          userName: "gianni",
          apiToken: "stale",
          customHeaders: [:]
        )
      ],
      key: .audiobookshelfConnection
    )
    service.setup()
    let viewModel = AudiobookShelfConnectionViewModel(connectionService: service)

    viewModel.prepareReauth()
    // The server moved: the user edits the address before reconnecting.
    viewModel.form.serverUrl = "https://moved.example.com"
    http.statusPayload = Data(#"{"authMethods":["local"]}"#.utf8)
    http.pingPayload = Data(#"{"success":true}"#.utf8)
    try await viewModel.handleConnectAction()

    viewModel.form.username = "gianni"
    viewModel.form.password = "pw"
    try await viewModel.handleSignInAction()

    XCTAssertEqual(service.connections.count, 1, "the moved server must update its row, not fork")
    XCTAssertEqual(service.connections.first?.url.absoluteString, "https://moved.example.com")
    XCTAssertEqual(service.connections.first?.id, "a", "outbound references survive the move")
  }

  // MARK: - Sign-out

  /// Found on device: signing out the last server from a details sheet redrew the sheet into the old
  /// URL form, with the presenter's Done and the form's Connect fighting in one toolbar. Sign-out is
  /// deletion — the presenting screen dismisses, and nothing here may re-enter a sign-in flow.
  func testSignOutNeverRedrawsASignInFormInPlace() throws {
    try keychain.set(
      [
        AudiobookShelfConnectionData(
          id: "a",
          url: URL(string: serverURL)!,
          serverName: "Home",
          userID: "u1",
          userName: "gianni",
          apiToken: "t",
          customHeaders: [:]
        )
      ],
      key: .audiobookshelfConnection
    )
    service.setup()
    let viewModel = AudiobookShelfConnectionViewModel(connectionService: service, mode: .viewDetails)

    viewModel.handleSignOutAction()

    XCTAssertTrue(service.connections.isEmpty)
    XCTAssertNil(viewModel.signInFlow, "no in-place redraw — the presenter dismisses instead")
    XCTAssertTrue(viewModel.flowPath.isEmpty)
  }

  // MARK: - The step after Connect

  /// The routing decision the redesigned flow hangs on: which screen Connect lands you on, per what
  /// the server offers. Wrong routing is invisible in review — a server config you don't have renders
  /// a screen you never see — so the whole matrix is pinned.
  func testConnectRoutesToTheRightStep() async throws {
    struct Row {
      let authMethods: String
      let scheme: String
      let expected: [ConnectionFlowStep]
      let passwordOffered: Bool
    }
    let matrix: [Row] = [
      // Both methods → the chooser, password still offered there.
      Row(authMethods: #"["local","openid"]"#, scheme: "https", expected: [.method], passwordOffered: true),
      // SSO-only → still the chooser (one primary button beats auto-launching a browser),
      // and the password button must NOT exist — the form cannot work.
      Row(authMethods: #"["openid"]"#, scheme: "https", expected: [.method], passwordOffered: false),
      // Password-only → skip the chooser entirely.
      Row(authMethods: #"["local"]"#, scheme: "https", expected: [.password], passwordOffered: true),
      // SSO advertised but refused over plaintext → not offered, so password is the only path.
      Row(authMethods: #"["local","openid"]"#, scheme: "http", expected: [.password], passwordOffered: true),
      // Probe answered nothing usable → fail safe toward the password form.
      Row(authMethods: "[]", scheme: "https", expected: [.password], passwordOffered: true),
    ]

    for row in matrix {
      let viewModel = AudiobookShelfConnectionViewModel(connectionService: service, mode: .addServer)
      viewModel.form.serverUrl = "\(row.scheme)://abs.example.com"
      http.statusPayload = Data(#"{"authMethods":"#.appending(row.authMethods).appending("}").utf8)
      http.pingPayload = Data(#"{"success":true}"#.utf8)

      try await viewModel.handleConnectAction()

      XCTAssertEqual(viewModel.flowPath, row.expected, "authMethods \(row.authMethods) over \(row.scheme)")
      XCTAssertEqual(
        viewModel.supportsPasswordSignIn,
        row.passwordOffered,
        "authMethods \(row.authMethods) over \(row.scheme)"
      )
    }
  }

  /// The dead-end config: SSO-only server over plaintext. We refuse SSO on http and the password
  /// form cannot authenticate, so Connect must fail with the reason — landing the user back on the
  /// address screen with its scheme control — rather than route to a form that cannot work.
  func testConnectFailsWhenNoSignInMethodCanWork() async {
    let viewModel = AudiobookShelfConnectionViewModel(connectionService: service, mode: .addServer)
    viewModel.form.serverUrl = "http://abs.example.com"
    http.statusPayload = Data(#"{"authMethods":["openid"]}"#.utf8)
    http.pingPayload = Data(#"{"success":true}"#.utf8)

    do {
      try await viewModel.handleConnectAction()
      XCTFail("expected insecureTransport")
    } catch let error as IntegrationError {
      guard case .insecureTransport = error else {
        return XCTFail("expected insecureTransport, got \(error)")
      }
    } catch {
      XCTFail("expected IntegrationError, got \(error)")
    }
    XCTAssertTrue(viewModel.flowPath.isEmpty, "a failed Connect must not push any screen")
    if case .enteringCredentials = viewModel.signInFlow {
      XCTFail("a failed Connect must not advance the sign-in flow")
    }
  }

  func testReauthAndCancelClearTheFlowPath() async throws {
    let viewModel = AudiobookShelfConnectionViewModel(connectionService: service, mode: .addServer)
    viewModel.form.serverUrl = serverURL
    http.statusPayload = Data(#"{"authMethods":["local"]}"#.utf8)
    http.pingPayload = Data(#"{"success":true}"#.utf8)
    try await viewModel.handleConnectAction()
    XCTAssertEqual(viewModel.flowPath, [.password])

    viewModel.handleCancelAddServerAction()

    XCTAssertTrue(viewModel.flowPath.isEmpty, "an abandoned flow must not leave pushed screens behind")
  }

  // MARK: - Capability probe

  /// The case the probe used to miss entirely: an admin who disabled local auth. `authMethods` then
  /// omits "local", and offering a password form anyway strands the user on a form that cannot work.
  func testCapabilityProbeDetectsAnSSOOnlyServer() async {
    http.statusPayload = Data(#"{"authMethods":["openid"]}"#.utf8)

    let capabilities = await service.fetchCapabilities(at: serverURL)

    XCTAssertTrue(capabilities.supportsOIDC)
    XCTAssertFalse(capabilities.supportsLocal)
  }

  /// A server that predates `authMethods` (or answers something unrecognisable) must keep its
  /// password form — hiding the only sign-in path a server may have is the unsafe direction.
  func testCapabilityProbeFailsSafeTowardLocalAuth() async {
    for payload in ["{}", #"{"authMethods":[]}"#, "not json at all"] {
      http.statusPayload = Data(payload.utf8)

      let capabilities = await service.fetchCapabilities(at: serverURL)

      XCTAssertFalse(capabilities.supportsOIDC, "payload: \(payload)")
      XCTAssertTrue(capabilities.supportsLocal, "payload: \(payload)")
    }
  }

  func testCapabilityProbeReadsBothMethodsAndTheProviderLabel() async {
    http.statusPayload = Data(
      #"{"authMethods":["local","openid"],"authFormData":{"authOpenIDButtonText":"Login with Pocket ID"}}"#.utf8
    )

    let capabilities = await service.fetchCapabilities(at: serverURL)

    XCTAssertTrue(capabilities.supportsLocal)
    XCTAssertTrue(capabilities.supportsOIDC)
    XCTAssertEqual(capabilities.oidcButtonText, "Login with Pocket ID")
  }
}

// MARK: - Stubs

/// Answers the plain-HTTP calls the view model makes (`/ping`, `/status`) plus the OIDC exchange.
/// `AudiobookShelfConnectionService` still owns a private `URLSession` for `/ping` and `/status`, so
/// those are routed through here only where the service uses the injected client.
/// `@unchecked Sendable`: a single-threaded test double whose knobs are set before use, matching
/// `KeychainServiceMock`. `IntegrationHTTPClient` is `Sendable`, so the conformance is required.
private final class OIDCHTTPStub: IntegrationHTTPClient, @unchecked Sendable {
  var pingPayload = Data(#"{"success":true}"#.utf8)
  var statusPayload = Data("{}".utf8)
  var exchangePayload = Data(#"{"user":{"token":"t","id":"u1","username":"gianni"}}"#.utf8)
  var exchangeStatus = 200

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let path = request.url?.path ?? ""
    let payload: Data
    if path.hasSuffix("/status") {
      payload = statusPayload
    } else if path.hasSuffix("/ping") {
      payload = pingPayload
    } else {
      payload = exchangePayload
    }
    let status = path.contains("openid") ? exchangeStatus : 200
    let response = HTTPURLResponse(
      url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil
    )!
    return (payload, response)
  }

  func redirectLocation(for request: URLRequest) async throws -> URL {
    var components = URLComponents(string: "https://idp.example.com/authorize")!
    let state = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
      .queryItems?.first { $0.name == "state" }?.value
    components.queryItems = [URLQueryItem(name: "state", value: state)]
    return components.url!
  }
}

@MainActor
private final class OIDCWebAuthStub: WebAuthenticating {
  var code = "the-code"

  func authenticate(
    url: URL,
    callbackScheme: String,
    prefersEphemeralSession: Bool
  ) async throws -> URL {
    let state = URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?.first { $0.name == "state" }?.value
    var components = URLComponents(string: "audiobookshelf://oauth")!
    components.queryItems = [
      URLQueryItem(name: "code", value: code),
      URLQueryItem(name: "state", value: state),
    ]
    return components.url!
  }
}
