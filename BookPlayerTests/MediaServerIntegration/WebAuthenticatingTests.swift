//
//  WebAuthenticatingTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AuthenticationServices
@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

/// Pins `WebAuthHandshake`'s resume contract. Every case here is a real ordering the browser flow can hit, and
/// each failure mode is silent-but-fatal: resuming a checked continuation twice traps the process, never
/// resuming hangs the sign-in forever, and losing a cancellation presents a browser sheet for a task
/// nobody is waiting on. None of it is observable from the outside, hence direct tests.
final class WebAuthenticatingTests: XCTestCase {
  private func makeSession() -> ASWebAuthenticationSession {
    ASWebAuthenticationSession(
      url: URL(string: "https://idp.example.com/authorize")!,
      callback: .customScheme("audiobookshelf")
    ) { _, _ in }
  }

  /// `withTaskCancellationHandler` fires `onCancel` immediately when the surrounding Task is *already*
  /// cancelled — before the operation closure has handed over the continuation. The continuation must
  /// still be resumed, or the caller waits forever.
  func testCancelBeforeAdoptStillResumesTheContinuation() async {
    let handshake = WebAuthHandshake()
    handshake.cancel()

    do {
      _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
        handshake.adopt(continuation)
      }
      XCTFail("expected the pre-cancelled handshake to resume with an error")
    } catch {
      XCTAssertTrue(error is CancellationError)
    }
  }

  /// …and in that same ordering the session must never be started, or the user sees a browser sheet for
  /// a flow that was already abandoned.
  func testAdoptSessionRefusesAfterCancellation() {
    let handshake = WebAuthHandshake()
    handshake.cancel()

    XCTAssertFalse(
      handshake.adopt(makeSession()),
      "a cancelled handshake must tell the caller not to start the session"
    )
  }

  func testAdoptSessionSucceedsOnTheNormalPath() {
    XCTAssertTrue(WebAuthHandshake().adopt(makeSession()))
  }

  /// `start()` returning false and the completion handler firing are not mutually exclusive, so `finish`
  /// gets called twice on that path. The second call must be a no-op — resuming twice would trap.
  func testFinishIsIdempotent() async throws {
    let handshake = WebAuthHandshake()
    let url = URL(string: "audiobookshelf://oauth?code=abc")!

    let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
      handshake.adopt(continuation)
      handshake.finish(.success(url))
      // Any of these would trap the process if `finish` were not guarded.
      handshake.finish(.success(url))
      handshake.finish(.failure(CancellationError()))
      handshake.cancel()
    }

    XCTAssertEqual(result, url)
  }

  /// Cancellation arriving after the continuation is adopted but before the session is — the window the
  /// `isTerminal` flag exists to close.
  func testCancelBetweenAdoptingContinuationAndSession() async {
    let handshake = WebAuthHandshake()

    do {
      _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
        handshake.adopt(continuation)
        handshake.cancel()
        XCTAssertFalse(handshake.adopt(makeSession()))
      }
      XCTFail("expected cancellation to surface")
    } catch {
      XCTAssertTrue(error is CancellationError)
    }
  }

  /// A completed handshake that is cancelled afterwards (sheet already dismissed) must keep its result.
  func testCancelAfterCompletionDoesNotOverrideTheResult() async throws {
    let handshake = WebAuthHandshake()
    let url = URL(string: "audiobookshelf://oauth?code=abc")!

    let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
      handshake.adopt(continuation)
      _ = handshake.adopt(makeSession())
      handshake.finish(.success(url))
      handshake.cancel()
    }

    XCTAssertEqual(result, url)
  }
}
