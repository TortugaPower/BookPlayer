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
}
