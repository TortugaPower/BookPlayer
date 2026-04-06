//
//  AudiobookShelfConnectionData.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 14/11/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

struct AudiobookShelfConnectionData: Codable, Identifiable {
  let id: String
  let url: URL
  let serverName: String
  let userID: String
  let userName: String
  let apiToken: String
  var selectedLibraryId: String?

  init(
    id: String = UUID().uuidString,
    url: URL,
    serverName: String,
    userID: String,
    userName: String,
    apiToken: String,
    selectedLibraryId: String? = nil
  ) {
    self.id = id
    self.url = url
    self.serverName = serverName
    self.userID = userID
    self.userName = userName
    self.apiToken = apiToken
    self.selectedLibraryId = selectedLibraryId
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
    self.url = try container.decode(URL.self, forKey: .url)
    self.serverName = try container.decode(String.self, forKey: .serverName)
    self.userID = try container.decode(String.self, forKey: .userID)
    self.userName = try container.decode(String.self, forKey: .userName)
    self.apiToken = try container.decode(String.self, forKey: .apiToken)
    self.selectedLibraryId = try container.decodeIfPresent(String.self, forKey: .selectedLibraryId)
  }
}

extension AudiobookShelfConnectionData: CustomDebugStringConvertible {
  var debugDescription: String {
    let apiTokenDebugDesc = apiToken.isEmpty ? "<empty>" : "<redacted>"
    return "AudiobookShelfConnectionData(\(url), \(serverName), \(userID), \(userName), \(apiTokenDebugDesc))"
  }
}
