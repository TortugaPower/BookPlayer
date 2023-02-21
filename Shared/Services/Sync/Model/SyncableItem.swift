//
//  SyncableItem.swift
//  BookPlayer
//
//  Created by gianni.carlo on 8/7/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

public struct SyncableItem {
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
    "type"
  ]
}

extension SyncableItem: Decodable {
  enum CodingKeys: CodingKey {
    case relativePath
    case originalFileName
    case title
    case details
    case speed
    case currentTime
    case duration
    case percentCompleted
    case isFinished
    case orderRank
    case lastPlayDateTimestamp
    case type
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.relativePath = try container.decode(String.self, forKey: .relativePath)
    self.originalFileName = try container.decode(String.self, forKey: .originalFileName)
    self.title = try container.decode(String.self, forKey: .title)
    self.details = try container.decodeIfPresent(String.self, forKey: .details) ?? ""
    self.speed = try container.decodeIfPresent(Double.self, forKey: .speed)
    self.currentTime = try container.decodeIfPresent(Double.self, forKey: .currentTime) ?? 0.0
    self.duration = try container.decodeIfPresent(Double.self, forKey: .duration) ?? 0.0
    self.percentCompleted = try container.decodeIfPresent(Double.self, forKey: .percentCompleted) ?? 0.0
    self.isFinished = try container.decode(Bool.self, forKey: .isFinished)
    self.orderRank = try container.decode(Int.self, forKey: .orderRank)
    self.lastPlayDateTimestamp = try container.decodeIfPresent(Double.self, forKey: .lastPlayDateTimestamp)
    self.type = try container.decode(SimpleItemType.self, forKey: .type)
  }
}
