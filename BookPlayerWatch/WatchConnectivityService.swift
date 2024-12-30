//
//  WatchConnectivityService.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 14/3/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import WatchConnectivity

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
