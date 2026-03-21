//
//  JellyfinConnectionData.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-20.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation

public struct JellyfinConnectionData: Codable {
  let url: URL
  let serverName: String
  let userID: String
  let userName: String
  let accessToken: String
}

extension JellyfinConnectionData: CustomDebugStringConvertible {
  public var debugDescription: String {
    let accessTokenDebugDesc = accessToken.isEmpty ? "<empty>" : "<redacted>"
    return "JellyfinConnectionData(\(url), \(serverName), \(userID), \(userName), \(accessTokenDebugDesc))"
  }
}
