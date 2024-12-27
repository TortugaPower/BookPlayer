//
//  PhoneWatchConnectivityService.swift
//  BookPlayer
//
//  Created by gianni.carlo on 14/3/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import WatchConnectivity

public class PhoneWatchConnectivityService: NSObject, WCSessionDelegate {
  let libraryService: LibraryServiceProtocol
  let playbackService: PlaybackServiceProtocol
  let playerManager: PlayerManagerProtocol
  /// Flag to avoid calling activate more than once from outside the service
  var didStartSession = false
  /// Flag used to register observers only once
  var didRegisterObservers = false

  private var disposeBag = Set<AnyCancellable>()

  public init(
    libraryService: LibraryServiceProtocol,
    playbackService: PlaybackServiceProtocol,
    playerManager: PlayerManagerProtocol
  ) {
    self.libraryService = libraryService
    self.playbackService = playbackService
    self.playerManager = playerManager

    super.init()
  }

  func bindObservers() {
    NotificationCenter.default.publisher(for: .bookReady, object: nil)
      .sink(receiveValue: { [weak self] notification in
        guard
          let self = self,
          let loaded = notification.userInfo?["loaded"] as? Bool,
          loaded == true
        else {
          return
        }

        self.sendApplicationContext()
      })
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .chapterChange, object: nil)
      .sink(receiveValue: { [weak self] _ in
        self?.sendApplicationContext()
      })
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .bookPlayed, object: nil)
      .sink(receiveValue: { [weak self] notification in
        guard
          let self = self,
          self.session?.activationState == .activated,
          let currentItem = notification.userInfo?["book"] as? PlayableItem
        else {
          return
        }

        self.sendMessage(message: [
          "command": "play" as AnyObject,
          "identifier": currentItem.relativePath as AnyObject
        ])
      })
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .bookPaused, object: nil)
      .sink(receiveValue: { [weak self] _ in
        guard
          self?.session?.activationState == .activated
        else {
          return
        }

        self?.sendMessage(message: [
          "command": "pause" as AnyObject,
        ])
      })
      .store(in: &disposeBag)
  }

  private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil

  public var validSession: WCSession? {
    if let session = self.session, session.isPaired, session.isWatchAppInstalled {
      return session
    } else {
      return nil
    }
  }

  public func startSession(_ delegate: WCSessionDelegate? = nil) {
    guard !self.didStartSession else { return }

    self.didStartSession = true
    self.session?.delegate = delegate ?? self
    self.session?.activate()
  }

  public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    self.sendApplicationContext()

    // Register observers only once
    if !didRegisterObservers {
      didRegisterObservers = true
      bindObservers()
    }
  }

  public func sessionDidBecomeInactive(_ session: WCSession) {}

  public func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }

  public func sendApplicationContext() {
    guard self.validSession != nil else { return }

    let applicationContext = self.generateApplicationContext()

    try? self.updateApplicationContext(
      applicationContext: self.getDictionaryFromContext(applicationContext)
    )

    guard
      self.session?.activationState == .activated,
      let applicationContextData = try? JSONEncoder().encode(applicationContext)
    else { return }

    self.sendMessageData(data: applicationContextData)
  }

  public func generateApplicationContext() -> WatchApplicationContext {
    var recentItems = [PlayableItem]()
    if let recentBooks = self.libraryService.getLastPlayedItems(limit: 20) {
      recentItems = recentBooks.compactMap({ [weak self] in
        try? self?.playbackService.getPlayableItem(from: $0)
      })
    }

    return WatchApplicationContext(
      recentItems: recentItems,
      currentItem: self.playerManager.currentItem,
      rate: self.playerManager.currentSpeed,
      rewindInterval: Int(PlayerManager.rewindInterval),
      forwardInterval: Int(PlayerManager.forwardInterval),
      boostVolume: UserDefaults.standard.bool(forKey: Constants.UserDefaults.boostVolumeEnabled)
    )
  }

  public func getDictionaryFromContext(_ applicationContext: WatchApplicationContext) -> [String: AnyObject] {
    let encoder = JSONEncoder()

    return [
      "recentItems": (try? encoder.encode(applicationContext.recentItems)) as AnyObject,
      "currentItem": (try? encoder.encode(applicationContext.currentItem)) as AnyObject,
      "rate": (try? encoder.encode(applicationContext.rate)) as AnyObject,
      "rewindInterval": (try? encoder.encode(applicationContext.rewindInterval)) as AnyObject,
      "forwardInterval": (try? encoder.encode(applicationContext.forwardInterval)) as AnyObject,
      "boostVolume": (try? encoder.encode(applicationContext.boostVolume)) as AnyObject
    ]
  }
}

// MARK: Application Context

// use when your app needs only the latest information
// if the data was not sent, it will be replaced
extension PhoneWatchConnectivityService {
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
}

// MARK: Interactive Messaging

extension PhoneWatchConnectivityService {
  // Live messaging! App has to be reachable when sending messages from the phone
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

  public func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
    NotificationCenter.default.post(name: .messageReceived, object: nil, userInfo: message)
    replyHandler(["success": true])
  }

  public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    NotificationCenter.default.post(name: .messageReceived, object: nil, userInfo: message)
  }

  /// Only used for refresh command on the phone side
  public func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
    guard
      let jsonObject = try? JSONSerialization.jsonObject(with: messageData, options: .mutableLeaves) as? [String: Any],
      let action = CommandParser.parse(jsonObject),
      action.command == .refresh
    else {
      replyHandler(Data())
      return
    }

    let applicationContext = generateApplicationContext()

    guard let applicationContextData = try? JSONEncoder().encode(applicationContext) else { return }

    replyHandler(applicationContextData)
  }
}
