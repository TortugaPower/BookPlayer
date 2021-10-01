//
//  WatchConnectivityService.swift
//  BookPlayerWatch Extension
//
//  Created by Gianni Carlo on 4/26/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import WatchConnectivity

public class WatchConnectivityService: NSObject, WCSessionDelegate {
  let dataManager: DataManager

  public init(dataManager: DataManager) {
    self.dataManager = dataManager
  }

  private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil

  public var validSession: WCSession? {
    // paired - the user has to have their device paired to the watch
    // watchAppInstalled - the user must have your watch app installed

    // Note: if the device is paired, but your watch app is not installed
    // consider prompting the user to install it for a better experience

#if os(iOS)
    if let session = self.session, session.isPaired, session.isWatchAppInstalled {
      return session
    } else {
      return nil
    }
#elseif os(watchOS)
    return WCSession.default
#endif
  }

  public func startSession(_ delegate: WCSessionDelegate? = nil) {
    self.session?.delegate = delegate ?? self
    self.session?.activate()
  }

  public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
#if os(iOS)
    self.sendApplicationContext()
#elseif os(watchOS)
    // For some reason, the first message is always lost
    self.sendMessage(message: [:])
#endif
  }

#if os(iOS)
  public func sessionDidBecomeInactive(_ session: WCSession) {}

  public func sessionDidDeactivate(_ session: WCSession) {}

  public func sendApplicationContext() {
    guard self.validReachableSession != nil,
          let library = try? self.dataManager.getLibrary() else { return }

    guard let jsonData = try? JSONEncoder().encode(library) else {
      return
    }

    let rewind = UserDefaults.standard.double(forKey: Constants.UserDefaults.rewindInterval.rawValue)
    let forward = UserDefaults.standard.double(forKey: Constants.UserDefaults.forwardInterval.rawValue)

    try? self.updateApplicationContext(applicationContext: ["library": jsonData as AnyObject,
                                                            "rewindInterval": rewind as AnyObject,
                                                            "forwardInterval": forward as AnyObject])
  }
#endif
}

// MARK: Application Context

// use when your app needs only the latest information
// if the data was not sent, it will be replaced
extension WatchConnectivityService {
  // Sender
  public func updateApplicationContext(applicationContext: [String: AnyObject]) throws {
    if let session = validSession {
      do {
        try session.updateApplicationContext(applicationContext)
      } catch {
        throw error
      }
    }
  }

  // Receiver
  public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    DispatchQueue.main.async {
      NotificationCenter.default.post(name: .contextUpdate, object: nil, userInfo: applicationContext)
    }
  }
}

// MARK: User Info

// use when your app needs all the data
// FIFO queue
extension WatchConnectivityService {
  // Sender
  public func transferUserInfo(userInfo: [String: AnyObject]) -> WCSessionUserInfoTransfer? {
    return self.validSession?.transferUserInfo(userInfo)
  }

  public func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
    // implement this on the sender if you need to confirm that
    // the user info did in fact transfer
  }

  // Receiver
  public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    // handle receiving user info
    DispatchQueue.main.async {
      // make sure to put on the main queue to update UI!
    }
  }
}

// MARK: Transfer File

extension WatchConnectivityService {
  // Sender
  public func transferFile(file: NSURL, metadata: [String: AnyObject]) -> WCSessionFileTransfer? {
    return self.validSession?.transferFile(file as URL, metadata: metadata)
  }

  public func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
    // handle filed transfer completion
  }

  // Receiver
  public func session(_ session: WCSession, didReceive file: WCSessionFile) {
    print("======= received file: ", file)
    // handle receiving file
    DispatchQueue.main.async {
      // make sure to put on the main queue to update UI!
    }
  }
}

// MARK: Interactive Messaging

extension WatchConnectivityService {
  // Live messaging! App has to be reachable
  public var validReachableSession: WCSession? {
    if let session = validSession, session.isReachable {
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

  // Receiver
  public func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
    // handle receiving message
    DispatchQueue.main.async {
      // make sure to put on the main queue to update UI!
      NotificationCenter.default.post(name: .messageReceived, object: nil, userInfo: message)
    }
  }

  public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    self.session(session, didReceiveMessage: message) { _ in }
  }

  public func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
    // handle receiving message data
    DispatchQueue.main.async {
      // make sure to put on the main queue to update UI!
    }
  }
}
