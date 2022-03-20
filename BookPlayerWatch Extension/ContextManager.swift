//
//  ContextManager.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 18/2/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerWatchKit
import Foundation
import SwiftUI
import Combine

class ContextManager: ObservableObject {
  let watchConnectivityService = WatchConnectivityService()

  @Published var isConnecting = true
  @Published var isPlaying = false
  @Published var applicationContext = WatchApplicationContext(
    recentItems: [],
    currentItem: nil,
    rate: 1.0,
    rewindInterval: nil,
    forwardInterval: nil,
    boostVolume: false
  )

  var items: [PlayableItem] {
    return applicationContext.recentItems
  }

  init() {
    self.watchConnectivityService.didActivateSession = { [weak self] in
      DispatchQueue.main.async {
        self?.isConnecting = false
      }
    }

    self.watchConnectivityService.didReceiveData = { [weak self] messageData in
      guard
        let receivedContext = try? JSONDecoder().decode(WatchApplicationContext.self, from: messageData)
      else {
        return
      }

      DispatchQueue.main.async {
        self?.applicationContext = receivedContext
      }
    }

    self.watchConnectivityService.didReceiveContext = { [weak self] receivedContext in
      guard let context = self?.parseApplicationContext(receivedContext) else {
        return
      }

      DispatchQueue.main.async {
        self?.applicationContext = context
      }
    }

    self.watchConnectivityService.startSession()
  }

  func handleItemSelected(_ item: PlayableItem) {
    guard self.applicationContext.currentItem != item else { return }

    let message = [
      "command": Command.play.rawValue as AnyObject,
      "identifier": item.relativePath as AnyObject
    ]

    self.watchConnectivityService.sendMessage(message: message)
    self.applicationContext.currentItem = item
    self.isPlaying = true
  }

  func handleChapterSelected(_ chapter: PlayableChapter) {
    self.watchConnectivityService.sendMessage(message: [
      "command": Command.chapter.rawValue as AnyObject,
      "start": "\(chapter.start)" as AnyObject
    ])
  }

  func handleNewSpeed(_ rate: Float) {
    let roundedValue = round(rate * 100) / 100.0

    guard roundedValue >= 0.5 && roundedValue <= 4.0 else { return }

    self.watchConnectivityService.sendMessage(message: [
      "command": Command.speed.rawValue as AnyObject,
      "rate": "\(rate)" as AnyObject
    ])

    self.applicationContext.rate = roundedValue
  }

  func handleNewSpeedJump() {
    let rate: Float

    if self.applicationContext.rate == 4.0 {
      rate = 0.5
    } else {
      rate = min(self.applicationContext.rate + 0.5, 4.0)
    }

    let roundedValue = round(rate * 100) / 100.0

    self.watchConnectivityService.sendMessage(message: [
      "command": Command.speed.rawValue as AnyObject,
      "rate": "\(rate)" as AnyObject
    ])

    self.applicationContext.rate = roundedValue
  }

  func handleBoostVolumeToggle() {
    self.applicationContext.boostVolume = !self.applicationContext.boostVolume

    self.watchConnectivityService.sendMessage(message: [
      "command": Command.boostVolume.rawValue as AnyObject,
      "isOn": "\(self.applicationContext.boostVolume)" as AnyObject
    ])
  }

  func handleSkip(_ direction: SkipDirection) {
    let payload: [String: AnyObject]

    switch direction {
    case .back:
      payload = ["command": Command.skipRewind.rawValue as AnyObject]
    case .forward:
      payload = ["command": Command.skipForward.rawValue as AnyObject]
    }

    self.watchConnectivityService.sendMessage(message: payload)
  }

  func handlePlayPause() {
    var payload = [String: AnyObject]()

    if self.isPlaying {
      payload["command"] = Command.pause.rawValue as AnyObject
    } else {
      payload["command"] = Command.play.rawValue as AnyObject
    }

    if let currentItem = self.applicationContext.currentItem {
      payload["identifier"] = currentItem.relativePath as AnyObject
    }

    self.watchConnectivityService.sendMessage(message: payload)

    self.isPlaying = !self.isPlaying
  }

  func requestData() {
    let encoder = JSONEncoder()
    let data = try! encoder.encode(["command": Command.refresh.rawValue])

    self.watchConnectivityService.sendMessageData(
      data: data,
      replyHandler: self.watchConnectivityService.didReceiveData
    )
  }

  func parseApplicationContext(_ dictionary: [String: Any]) -> WatchApplicationContext {
    let decoder = JSONDecoder()

    var recentItems = [PlayableItem]()
    if let data = dictionary["recentItems"] as? Data {
      recentItems = (try? decoder.decode([PlayableItem].self, from: data)) ?? []
    }

    var currentItem: PlayableItem?
    if let data = dictionary["currentItem"] as? Data {
      currentItem = try? decoder.decode(PlayableItem.self, from: data)
    }

    var rate: Float = 1.0
    if let data = dictionary["rate"] as? Data {
      rate = (try? decoder.decode(Float.self, from: data)) ?? 1.0
    }

    var rewindInterval: Int?
    if let data = dictionary["rewindInterval"] as? Data {
      rewindInterval = try? decoder.decode(Int.self, from: data)
    }

    var forwardInterval: Int?
    if let data = dictionary["forwardInterval"] as? Data {
      forwardInterval = try? decoder.decode(Int.self, from: data)
    }

    var boostVolume = false
    if let data = dictionary["boostVolume"] as? Data {
      boostVolume = (try? decoder.decode(Bool.self, from: data)) ?? false
    }

    return WatchApplicationContext(
      recentItems: recentItems,
      currentItem: currentItem,
      rate: rate,
      rewindInterval: rewindInterval,
      forwardInterval: forwardInterval,
      boostVolume: boostVolume
    )
  }
}
