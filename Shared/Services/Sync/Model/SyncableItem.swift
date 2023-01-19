//
//  SyncableItem.swift
//  BookPlayer
//
//  Created by gianni.carlo on 8/7/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

public struct SyncableItem: Decodable {
  let relativePath: String
  let originalFileName: String
  let title: String
  let details: String
  let speed: Double?
  let currentTime: Double
  let duration: Double
  let percentCompleted: Double
  let isFinished: Bool
  let orderRank: Int
  let lastPlayDateTimestamp: Double?
  let type: SimpleItemType

  static var fetchRequestProperties = [
    "relativePath",
    "originalFileName",
    "title",
    "details",
    "speed",
    "currentTime",
    "duration",
    "percentCompleted",
    "isFinished",
    "orderRank",
    "lastPlayDate",
    "type",
    "syncStatus"
  ]
}