//
//  WatchConnectivityService.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 14/3/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import WatchConnectivity

public enum WatchConnectivityError: LocalizedError {
  case notReachable
  case notSignedInOnPhone
  case authTransferFailed(String)

  public var errorDescription: String? {
    switch self {
    case .notReachable:
      return "watchapp_connect_error_description".localized
    case .notSignedInOnPhone:
      return "watch_signin_phone_required".localized
    case .authTransferFailed(let reason):
      return "watch_signin_failed".localized + ": \(reason)"
    }
  }
}

public struct WatchAuthResponse {
  public let token: String
  public let email: String
  public let accountId: String
  public let hasSubscription: Bool
  public let donationMade: Bool
}

public class WatchConnectivityService: NSObject, WCSessionDelegate {
  public var didReceiveData: ((Data) -> Void)?
  public var didReceiveContext: (([String: Any]) -> Void)?
  public var didActivateSession: (() -> Void)?

  private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil

  public var validSession: WCSession? {
    return WCSession.default
  }

  public func startSession(_ delegate: WCSessionDelegate? = nil) {
    self.session?.delegate = delegate ?? self
    self.session?.activate()
  }

  public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    // For some reason, the first message is always lost
    self.sendMessage(message: [:])

    self.didReceiveContext?(session.receivedApplicationContext)

    self.didActivateSession?()
  }
}

// MARK: Application Context

// use when your app needs only the latest information
// if the data was not sent, it will be replaced
extension WatchConnectivityService {
  // Receiver
  public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    self.didReceiveContext?(applicationContext)
  }
}

// MARK: Interactive Messaging

extension WatchConnectivityService {
  // Live messaging! App has to be reachable when sending messages from the phone
  public var validReachableSession: WCSession? {
    if let session = validSession {
      return session
    }

    return nil
  }

  // Sender
  public func sendMessage(message: [String: AnyObject],
                          replyHandler: (([String: Any]) -> Void)? = nil,
                          errorHandler: ((Error) -> Void)? = nil) {
    self.validReachableSession?.sendMessage(message, replyHandler: replyHandler, errorHandler: errorHandler)
  }

  public func send(message: [String: AnyObject]) throws {
    guard
      let session = self.validReachableSession,
      session.activationState == .activated
    else {
      throw WatchConnectivityError.notReachable
    }

    session.sendMessage(message, replyHandler: nil)
  }

  public func sendMessageData(data: Data,
                              replyHandler: ((Data) -> Void)? = nil,
                              errorHandler: ((Error) -> Void)? = nil) {
    self.validReachableSession?.sendMessageData(data, replyHandler: replyHandler, errorHandler: errorHandler)
  }

  public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    guard
      let action = CommandParser.parse(message)
    else {
      return
    }

    DispatchQueue.main.async {
      switch action.command {
      case .play:
        NotificationCenter.default.post(name: .bookPlaying, object: nil)
      case .pause:
        NotificationCenter.default.post(name: .bookPaused, object: nil)
      default:
        break
      }
    }
  }

  /// Only used to receive books data on the watch via live messaging
  public func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
    self.didReceiveData?(messageData)
  }
}

// MARK: - Auth Transfer from iPhone

extension WatchConnectivityService {
  /// Request authentication credentials from iPhone
  public func requestAuthFromiPhone() async throws -> WatchAuthResponse {
    guard let session = validReachableSession,
          session.activationState == .activated,
          session.isReachable else {
      throw WatchConnectivityError.notReachable
    }

    return try await withCheckedThrowingContinuation { continuation in
      let message: [String: Any] = ["command": "requestAuth"]

      session.sendMessage(message, replyHandler: { reply in
        if let error = reply["error"] as? String {
          switch error {
          case "notSignedIn":
            continuation.resume(throwing: WatchConnectivityError.notSignedInOnPhone)
          default:
            continuation.resume(throwing: WatchConnectivityError.authTransferFailed(error))
          }
          return
        }

        guard let token = reply["token"] as? String,
              let email = reply["email"] as? String,
              let accountId = reply["accountId"] as? String else {
          continuation.resume(throwing: WatchConnectivityError.authTransferFailed("invalidResponse"))
          return
        }

        let response = WatchAuthResponse(
          token: token,
          email: email,
          accountId: accountId,
          hasSubscription: reply["hasSubscription"] as? Bool ?? false,
          donationMade: reply["donationMade"] as? Bool ?? false
        )

        continuation.resume(returning: response)
      }, errorHandler: { error in
        continuation.resume(throwing: WatchConnectivityError.authTransferFailed(error.localizedDescription))
      })
    }
  }
}
