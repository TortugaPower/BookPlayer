//
//  ApiResponse.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 11/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

public enum ApiResponse {
  case matchUuid(MatchUuidsResponse)
}

public struct MatchUuidsResponse: Decodable {
    // Array of string keys that were successfully applied
    public let applied: [String]
    // Array of the conflict objects
    public let conflicts: [ItemConflict]

    public init(applied: [String], conflicts: [ItemConflict]) {
        self.applied = applied
        self.conflicts = conflicts
    }
}

public struct ItemConflict: Decodable {
    // Maps to the local sent "uuid" in your JSON
    public let key: String
    // Maps to the "uuid" in your JSON
    public let uuid: String

    public init(key: String, uuid: String) {
        self.key = key
        self.uuid = uuid
    }
}
