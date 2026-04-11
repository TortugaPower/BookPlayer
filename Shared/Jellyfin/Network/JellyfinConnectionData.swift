//
//  JellyfinConnectionData.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-20.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation

public struct JellyfinConnectionData: Codable {
  public let url: URL
  public let serverName: String
  public let userID: String
  public let userName: String
  public let accessToken: String
}

extension JellyfinConnectionData: CustomDebugStringConvertible {
  public var debugDescription: String {
    let accessTokenDebugDesc = accessToken.isEmpty ? "<empty>" : "<redacted>"
    return "JellyfinConnectionData(\(url), \(serverName), \(userID), \(userName), \(accessTokenDebugDesc))"
  }
  
  public func buildDownloadUrl(providerId: String) -> String {
    return "\(self.url.absoluteString)/items/\(providerId)/Download?api_key=\(self.accessToken)"
  }
}
