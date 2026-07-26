//
//  WebAuthenticating.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 25/7/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AuthenticationServices
import BookPlayerKit
import Foundation
import UIKit

/// Presents a browser-based authorization handshake and resolves with the redirect the provider
/// bounces back to our callback scheme. Behind a protocol so auth flows are testable without a
/// browser.
@MainActor
protocol WebAuthenticating {
  /// - Returns: the callback URL, e.g. `audiobookshelf://oauth?code=…&state=…`.
  /// - Throws: `CancellationError` when the user dismisses the sheet, so callers can stay silent on a
  ///   deliberate cancel while still surfacing genuine failures.
  func authenticate(
    url: URL,
    callbackScheme: String,
    prefersEphemeralSession: Bool
  ) async throws -> URL
}

/// `ASWebAuthenticationSession`-backed implementation.
///
/// Concentrating the session lifetime here is deliberate: getting it wrong produces a hard crash or
/// a silent hang, and doing it once means every flow inherits the fix.
@MainActor
final class WebAuthenticationSession: NSObject, WebAuthenticating, BPLogger {
  /// Holds the in-flight handshake. Doubles as the strong reference the system session needs (it
  /// tears its sheet down if released while suspended) and as the single-flight guard.
  private var pending: WebAuthHandshake?

  /// The window validated before starting. Resolved up front so the delegate never has to invent an
  /// anchor — handing `ASWebAuthenticationSession` a detached `UIWindow` is what produces
  /// `presentationContextInvalid`, one of the errors that can arrive *alongside* a `false` from
  /// `start()`.
  private var anchor: UIWindow?

  /// `nonisolated` so the owning services — which are built as `@Entry` environment placeholders
  /// outside any actor — can construct one as a default argument. Nothing isolated is touched here.
  nonisolated override init() {
    super.init()
  }

  func authenticate(
    url: URL,
    callbackScheme: String,
    prefersEphemeralSession: Bool
  ) async throws -> URL {
    guard pending == nil else {
      // Starting a second handshake would replace the strong reference to the first, releasing a
      // presented session whose completion handler may then never fire — leaking its continuation
      // and wedging that flow permanently. The UI also disables the entry point; this is the backstop.
      Self.logger.warning("refusing a concurrent web-auth session")
      throw IntegrationError.unexpectedResponse(code: nil)
    }

    guard let anchor = Self.foregroundWindow() else {
      // No eligible window means the sheet cannot be presented. Failing here is strictly better than
      // starting a session the framework will reject.
      Self.logger.warning("no foreground window scene available to present web auth from")
      throw IntegrationError.unexpectedResponse(code: nil)
    }
    self.anchor = anchor

    defer {
      pending = nil
      self.anchor = nil
    }

    let handshake = WebAuthHandshake()
    pending = handshake

    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        handshake.adopt(continuation)

        let session = ASWebAuthenticationSession(
          url: url,
          callback: .customScheme(callbackScheme)
        ) { callbackURL, error in
          if let error {
            // A deliberate dismissal is not a failure worth alerting about; everything else is.
            if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
              handshake.finish(.failure(CancellationError()))
            } else {
              handshake.finish(.failure(error))
            }
            return
          }
          guard let callbackURL else {
            handshake.finish(.failure(IntegrationError.unexpectedResponse(code: nil)))
            return
          }
          handshake.finish(.success(callbackURL))
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = prefersEphemeralSession

        // Bail before presenting anything if cancellation beat us here — `adopt` has already resumed
        // the continuation, and starting now would show a sheet for an abandoned task.
        guard handshake.adopt(session) else { return }

        if !session.start() {
          // `start()` returning false and the completion handler firing are *not* documented as
          // mutually exclusive — `presentationContextNotProvided` and `presentationContextInvalid`
          // are both start-time conditions whose only reporting channel is that handler. Resuming a
          // checked continuation twice traps, so `WebAuthHandshake` makes the first resume win.
          handshake.finish(.failure(IntegrationError.unexpectedResponse(code: nil)))
        }
      }
    } onCancel: {
      // Cancelling the surrounding Task has to tear the sheet down. Without this the continuation
      // stays suspended, the browser stays up, and a login the user *completes* later resumes into a
      // cancelled task and is silently thrown away.
      handshake.cancel()
    }
  }

  /// The only window we'll present from: one belonging to a foreground-active scene, which is what
  /// `ASWebAuthenticationSession` documents as the requirement for a valid anchor.
  private static func foregroundWindow() -> UIWindow? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) else {
      return nil
    }
    return scene.keyWindow ?? scene.windows.first
  }
}

extension WebAuthenticationSession: ASWebAuthenticationPresentationContextProviding {
  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    // `anchor` is validated before the session starts, so the fallback is unreachable in practice —
    // it exists only because the protocol requires a non-optional return.
    anchor ?? ASPresentationAnchor()
  }
}

/// One browser handshake: a checked continuation that can only be resumed once, plus the session to
/// dismiss on cancellation.
///
/// Locked rather than actor-isolated because the completion handler and the task-cancellation
/// callback can each arrive on an arbitrary thread. Resuming twice traps and never resuming hangs the
/// caller, so both outcomes funnel through `finish`.
/// Internal rather than private purely so `WebAuthenticatingTests` can pin the cancellation orderings
/// below — they are timing-dependent in production and would otherwise be untestable.
final class WebAuthHandshake: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<URL, Error>?
  private var session: ASWebAuthenticationSession?

  /// Set once the handshake reaches a terminal state — by `cancel()`, or by any `finish()`.
  ///
  /// `withTaskCancellationHandler` invokes `onCancel` *immediately* when the surrounding Task is
  /// already cancelled — which can happen before the operation closure has handed us either the
  /// continuation or the session. Without this flag that ordering silently loses the cancellation:
  /// `cancel()` finds both `nil` and does nothing, then the closure starts the session anyway and the
  /// user gets a browser sheet for work nobody is waiting on — and because `authenticate` never
  /// returns, its `defer` never clears `pending`, so every later attempt trips the single-flight guard.
  ///
  /// Set in `finish` as well as `cancel` so the rule is "terminal is terminal" rather than something
  /// that depends on which call sites happen to run in which order.
  private var isTerminal = false

  /// Stores the continuation, or resumes it straight away if cancellation already arrived.
  func adopt(_ continuation: CheckedContinuation<URL, Error>) {
    lock.lock()
    if isTerminal {
      lock.unlock()
      continuation.resume(throwing: CancellationError())
      return
    }
    self.continuation = continuation
    lock.unlock()
  }

  /// - Returns: `false` when cancellation already arrived, in which case the caller must **not** start
  ///   the session — the continuation has already been resumed.
  ///
  /// Deliberately **not** `@discardableResult`: obeying this value is the entire fix. Marking it
  /// discardable would let a future edit drop the `guard` at the call site, silently reintroduce the
  /// abandoned-sheet bug, and still compile with every test green.
  func adopt(_ session: ASWebAuthenticationSession) -> Bool {
    lock.lock()
    if isTerminal {
      lock.unlock()
      return false
    }
    self.session = session
    lock.unlock()
    return true
  }

  /// Resumes the continuation if it hasn't been resumed yet. Safe to call from any thread, and safe
  /// to call more than once.
  ///
  /// Also drops the session, which breaks a reference cycle: the session's completion handler
  /// captures this `WebAuthHandshake`, and the handshake holds the session. `ASWebAuthenticationSession`
  /// isn't documented to release its handler once it fires, so without this both objects outlive
  /// the flow — guaranteed when `start()` returns `false` and the handler never runs at all.
  /// `cancel()` reads the session before calling this, so dismissal is unaffected.
  func finish(_ result: Result<URL, Error>) {
    lock.lock()
    isTerminal = true
    let continuation = self.continuation
    self.continuation = nil
    self.session = nil
    lock.unlock()
    continuation?.resume(with: result)
  }

  /// Dismisses the sheet and unblocks the caller. `cancel()` is documented to invoke the completion
  /// handler, but resuming here as well costs nothing and removes any chance of a hang if it doesn't.
  func cancel() {
    lock.lock()
    isTerminal = true
    let session = self.session
    lock.unlock()
    finish(.failure(CancellationError()))
    Task { @MainActor in session?.cancel() }
  }
}
