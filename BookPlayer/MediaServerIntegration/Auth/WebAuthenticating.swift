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
  private var pending: Handshake?

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

    let handshake = Handshake()
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
        handshake.adopt(session)

        if !session.start() {
          // `start()` returning false and the completion handler firing are *not* documented as
          // mutually exclusive — `presentationContextNotProvided` and `presentationContextInvalid`
          // are both start-time conditions whose only reporting channel is that handler. Resuming a
          // checked continuation twice traps, so `Handshake` makes the first resume win.
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
private final class Handshake: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<URL, Error>?
  private var session: ASWebAuthenticationSession?

  func adopt(_ continuation: CheckedContinuation<URL, Error>) {
    lock.lock()
    self.continuation = continuation
    lock.unlock()
  }

  func adopt(_ session: ASWebAuthenticationSession) {
    lock.lock()
    self.session = session
    lock.unlock()
  }

  /// Resumes the continuation if it hasn't been resumed yet. Safe to call from any thread, and safe
  /// to call more than once.
  func finish(_ result: Result<URL, Error>) {
    lock.lock()
    let continuation = self.continuation
    self.continuation = nil
    lock.unlock()
    continuation?.resume(with: result)
  }

  /// Dismisses the sheet and unblocks the caller. `cancel()` is documented to invoke the completion
  /// handler, but resuming here as well costs nothing and removes any chance of a hang if it doesn't.
  func cancel() {
    lock.lock()
    let session = self.session
    lock.unlock()
    finish(.failure(CancellationError()))
    Task { @MainActor in session?.cancel() }
  }
}
