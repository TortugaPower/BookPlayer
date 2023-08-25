//
//  WatchApplicationContext.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 19/3/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

public struct WatchApplicationContext: Codable {
  public var recentItems: [PlayableItem]
  public var currentItem: PlayableItem?
  public var rate: Float
  public var rewindInterval: Int?
  public var forwardInterval: Int?
  public var boostVolume: Bool
  
  public init(
    recentItems: [PlayableItem],
    currentItem: PlayableItem?,
    rate: Float,
    rewindInterval: Int?,
    forwardInterval: Int?,
    boostVolume: Bool
  ) {
    self.recentItems = recentItems
    self.currentItem = currentItem
    self.rate = rate
    self.rewindInterval = rewindInterval
    self.forwardInterval = forwardInterval
    self.boostVolume = boostVolume
  }
}
