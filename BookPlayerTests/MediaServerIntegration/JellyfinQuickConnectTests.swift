//
//  JellyfinQuickConnectTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import JellyfinAPI
import XCTest

/// Covers the Quick Connect state machine and its user-facing error mapping — the two pieces where a
/// wrong branch is invisible until someone tries to sign in.
@MainActor
final class JellyfinQuickConnectTests: XCTestCase {
  private var keychain: KeychainServiceMock!
  private var viewModel: JellyfinConnectionViewModel!

  override func setUp() {
    super.setUp()
    keychain = KeychainServiceMock()
    viewModel = JellyfinConnectionViewModel(
      connectionService: JellyfinConnectionService(keychainService: keychain)
    )
  }

  override func tearDown() {
    keychain = nil
    viewModel = nil
    super.tearDown()
  }

  // MARK: - State mapping

  /// The regression this exists for. `QuickConnect.state` is `@Published` and starts at `.idle`, and
  /// `@Published` replays its current value to every new subscriber — so `.idle` is delivered once,
  /// guaranteed, immediately after the flow subscribes. Mapping it to `nil` dismissed the sheet a hop
  /// after presenting it and left the controller alive, so re-tapping the row became a silent no-op
  /// while a poller ran for its full ~16-minute budget.
  func testIdleDoesNotClearAnInFlightStatus() {
    viewModel.quickConnectStatus = .awaitingCode("ABC123")

    viewModel.handleQuickConnectStateChange(.idle)

    XCTAssertEqual(
      viewModel.quickConnectStatus,
      .awaitingCode("ABC123"),
      "`.idle` must be ignored — the replayed initial value would otherwise tear down the sheet"
    )
  }

  func testRetrievingCodeMapsThrough() {
    viewModel.handleQuickConnectStateChange(.retrievingCode)

    XCTAssertEqual(viewModel.quickConnectStatus, .retrievingCode)
  }

  /// The code has to survive verbatim — the user retypes it into their browser.
  func testPollingCarriesTheCodeThrough() {
    viewModel.handleQuickConnectStateChange(.polling(code: "7H2K9Q"))

    XCTAssertEqual(viewModel.quickConnectStatus, .awaitingCode("7H2K9Q"))
  }

  func testErrorSurfacesAsFailedWithANonEmptyMessage() {
    viewModel.handleQuickConnectStateChange(.error(.maxPollingHit))

    guard case .failed(let message) = viewModel.quickConnectStatus else {
      return XCTFail("expected .failed, got \(String(describing: viewModel.quickConnectStatus))")
    }
    XCTAssertFalse(message.isEmpty)
  }

  // MARK: - Error message mapping

  func testTimeoutAndNoCodeResolveToDistinctLocalizedStrings() {
    let timeout = JellyfinConnectionViewModel.message(for: .maxPollingHit)
    let noCode = JellyfinConnectionViewModel.message(for: .retrievingCodeFailed)

    // A missing entry in Localizable.strings resolves to the key itself, which is the failure mode here.
    XCTAssertNotEqual(timeout, "jellyfin_quick_connect_error_timeout")
    XCTAssertNotEqual(noCode, "jellyfin_quick_connect_error_no_code")
    XCTAssertNotEqual(timeout, noCode)
  }

  /// `.other` carries whatever `client.send` threw, which for a non-2xx is `Get.APIError`'s *debug*
  /// description ("Response status code was unacceptable: 401."). That must not reach the UI.
  func testOtherDoesNotLeakItsRawPayload() {
    let raw = "Response status code was unacceptable: 401."

    let message = JellyfinConnectionViewModel.message(for: .other(raw))

    XCTAssertNotEqual(message, raw, "the raw SDK/network string must not be shown to the user")
    XCTAssertFalse(message.contains("unacceptable"))
    XCTAssertFalse(message.isEmpty)
    XCTAssertNotEqual(message, "jellyfin_quick_connect_error_generic", "key missing from Base.lproj")
  }

  // MARK: - Cancellation during the token exchange

  /// `.authenticated` kicks off a network round-trip while the sheet still shows a live Cancel button.
  /// Cancelling has to reach that task: otherwise it completes anyway and persists a connection the user
  /// explicitly backed out of, or re-presents the dismissed sheet with an error for a finished flow.
  ///
  /// The `await` on the task handle is load-bearing. `handleQuickConnectStateChange` schedules the
  /// exchange on the MainActor, and this test body is already MainActor-isolated, so without awaiting it
  /// the task body cannot run before the assertions and the test passes no matter what the code does.
  ///
  /// What this actually pins: the **pre-flight** `guard !Task.isCancelled` at the top of
  /// `completeQuickConnectSignIn`. The fixture has no `pendingServer`, so the `do`/`catch` is never
  /// entered and the in-`catch` cancellation check is NOT covered by these tests. Covering it needs a
  /// seam to inject a throwing sign-in; until then that arm rests on inspection.
  func testCancellingClearsTheStatusEvenMidAuthentication() async {
    viewModel.handleQuickConnectStateChange(.authenticated(secret: "s3cr3t"))
    XCTAssertEqual(viewModel.quickConnectStatus, .authenticating)

    // Captured before cancelling: `handleCancelAlternativeSignIn` nils the handle, so reading it
    // afterwards awaits nothing and the assertions race ahead of the task body.
    let task = viewModel.quickConnectSignInTask
    viewModel.handleCancelAlternativeSignIn()
    await task?.value

    XCTAssertNil(
      viewModel.quickConnectStatus,
      "cancelling during the exchange must leave no status behind to re-present the sheet"
    )
  }

  /// Cancelling is not a failure — no error status is left behind for the sheet to re-present.
  ///
  /// Scope, same as above: this pins the pre-flight guard. The `Task.isCancelled` re-check inside the
  /// `catch` — the one that matters when cancellation lands *during* the round-trip, where it arrives as
  /// `URLError.cancelled` from Get's data loader rather than `CancellationError` — is not exercised here.
  func testCancellingDoesNotLeaveAFailureStatus() async {
    viewModel.handleQuickConnectStateChange(.authenticated(secret: "s3cr3t"))

    let task = viewModel.quickConnectSignInTask
    viewModel.handleCancelAlternativeSignIn()
    await task?.value

    if case .failed(let message) = viewModel.quickConnectStatus {
      XCTFail("cancellation must not surface as a failure, got: \(message)")
    }
  }

  /// The control for the two tests above. Same fixture, same entry point, only the cancellation removed —
  /// and it lands on `.failed` instead. That difference is what proves those two are observing the
  /// cancellation guard rather than any early return that would fire either way.
  func testUncancelledExchangeWithoutAPendingServerReportsFailure() async {
    viewModel.handleQuickConnectStateChange(.authenticated(secret: "s3cr3t"))

    await viewModel.quickConnectSignInTask?.value

    guard case .failed = viewModel.quickConnectStatus else {
      return XCTFail("expected .failed, got \(String(describing: viewModel.quickConnectStatus))")
    }
  }
}
