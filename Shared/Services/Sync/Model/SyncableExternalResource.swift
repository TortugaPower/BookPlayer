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
  public let hostId: String?

  static var fetchRequestProperties = [
    "providerName",
    "providerId",
    "syncStatus",
    "lastSyncedAt",
    "processedFile",
    "hostId"
  ]
}

extension SyncableExternalResource: Decodable {
  enum CodingKeys: String, CodingKey {
    case providerName
    case providerId
    case syncStatus
    case lastSyncedAt
    case processedFile
    case hostId
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.providerName = try container.decode(String.self, forKey: .providerName)
    self.providerId = try container.decode(String.self, forKey: .providerId)
    self.syncStatus = try container.decode(String.self, forKey: .syncStatus)
    // decodeIfPresent, not try?: an ABSENT key is fine, but a TYPE MISMATCH should
    // throw — LossyDecodableArray then drops (and logs) the malformed element instead
    // of silently nil-ing the field.
    self.lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
    // Absent processedFile must not drop the whole resource element (losing the book's
    // media-server link on this device); false is the conservative default — reprocess
    // rather than skip processing.
    self.processedFile = try container.decodeIfPresent(Bool.self, forKey: .processedFile) ?? false
    self.hostId = try container.decodeIfPresent(String.self, forKey: .hostId)
  }
}

extension SyncableExternalResource {
  public init(from item: SimpleExternalResource) {
    self.providerName = item.providerName
    self.providerId = item.providerId
    self.syncStatus = item.syncStatus
    self.lastSyncedAt = item.lastSyncedAt
    // Thread the real value: hardcoding true reported not-yet-processed resources as
    // processed to the server (and to every other device that syncs them down)
    self.processedFile = item.processedFile
    self.hostId = item.hostId
  }
}
