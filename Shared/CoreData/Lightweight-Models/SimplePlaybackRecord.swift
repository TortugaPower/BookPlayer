//
//  SimplePlaybackRecord.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 20/2/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

public struct SimplePlaybackRecord: Codable, Identifiable, Hashable {
  public var id: Date {
    return date
  }

  public var date: Date
  public var time: Double

  public init(time: Double, date: Date) {
    self.date = date
    self.time = time
  }
}

extension SimplePlaybackRecord {
  public init(from record: PlaybackRecord) {
    self.init(
      time: record.time,
      date: record.date
    )
  }
}
