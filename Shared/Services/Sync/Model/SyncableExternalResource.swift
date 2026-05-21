//
//  SyncableExternalResource.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 27/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

public struct SyncableExternalResource {
  public let providerName: String
  public let providerId: String
  public let syncStatus: String
  public let lastSyncedAt: Date?
  public let processedFile: Bool

  static var fetchRequestProperties = [
    "providerName",
    "providerId",
    "syncStatus",
    "lastSyncedAt",
    "processedFile"
  ]
}

extension SyncableExternalResource: Decodable {
  enum CodingKeys: String, CodingKey {
    case providerName
    case providerId
    case syncStatus
    case lastSyncedAt
    case processedFile
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.providerName = try container.decode(String.self, forKey: .providerName)
    self.providerId = try container.decode(String.self, forKey: .providerId)
    self.syncStatus = try container.decode(String.self, forKey: .syncStatus)
    self.lastSyncedAt = try? container.decode(Date.self, forKey: .lastSyncedAt)
    self.processedFile = try container.decode(Bool.self, forKey: .processedFile)
  }
}

extension SyncableExternalResource {
  public init(from item: SimpleExternalResource) {
    self.providerName = item.providerName
    self.providerId = item.providerId
    self.syncStatus = item.syncStatus
    self.lastSyncedAt = item.lastSyncedAt
    self.processedFile = true
  }
}
