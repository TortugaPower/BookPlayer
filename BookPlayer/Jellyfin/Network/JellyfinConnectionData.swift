//
//  JellyfinConnectionData.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-20.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation

struct JellyfinConnectionData: Codable {
  let url: URL
  let serverName: String
  let userID: String
  let userName: String
  let accessToken: String
  var selectedLibraryId: String?
}

extension JellyfinConnectionData: CustomDebugStringConvertible {
  var debugDescription: String {
    let accessTokenDebugDesc = accessToken.isEmpty ? "<empty>" : "<redacted>"
    return "JellyfinConnectionData(\(url), \(serverName), \(userID), \(userName), \(accessTokenDebugDesc))"
  }
}
