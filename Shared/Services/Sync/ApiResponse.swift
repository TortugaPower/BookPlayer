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
    let applied: [String]
    // Array of the conflict objects
    let conflicts: [ItemConflict]
}

public struct ItemConflict: Decodable {
    // Maps to the local sent "uuid" in your JSON
    let key: String
    // Maps to the "uuid" in your JSON
    let uuid: String
}
