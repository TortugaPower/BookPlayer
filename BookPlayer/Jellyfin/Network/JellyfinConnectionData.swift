//
//  JellyfinConnectionData.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-20.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation

struct JellyfinConnectionData: Codable, Identifiable {
  let id: String
  let url: URL
  let serverName: String
  let userID: String
  let userName: String
  let accessToken: String
  var selectedLibraryId: String?

  init(
    id: String = UUID().uuidString,
    url: URL,
    serverName: String,
    userID: String,
    userName: String,
    accessToken: String,
    selectedLibraryId: String? = nil
  ) {
    self.id = id
    self.url = url
    self.serverName = serverName
    self.userID = userID
    self.userName = userName
    self.accessToken = accessToken
    self.selectedLibraryId = selectedLibraryId
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
    self.url = try container.decode(URL.self, forKey: .url)
    self.serverName = try container.decode(String.self, forKey: .serverName)
    self.userID = try container.decode(String.self, forKey: .userID)
    self.userName = try container.decode(String.self, forKey: .userName)
    self.accessToken = try container.decode(String.self, forKey: .accessToken)
    self.selectedLibraryId = try container.decodeIfPresent(String.self, forKey: .selectedLibraryId)
  }
}

extension JellyfinConnectionData: CustomDebugStringConvertible {
  var debugDescription: String {
    let accessTokenDebugDesc = accessToken.isEmpty ? "<empty>" : "<redacted>"
    return "JellyfinConnectionData(\(url), \(serverName), \(userID), \(userName), \(accessTokenDebugDesc))"
  }
}
