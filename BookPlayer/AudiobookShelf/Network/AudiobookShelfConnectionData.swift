//
//  AudiobookShelfConnectionData.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 14/11/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

struct AudiobookShelfConnectionData: Codable {
  let url: URL
  let serverName: String
  let userID: String
  let userName: String
  let apiToken: String
  var selectedLibraryId: String?
  var customHeaders: [String: String] = [:]

  enum CodingKeys: String, CodingKey {
    case url, serverName, userID, userName, apiToken, selectedLibraryId, customHeaders
  }

  init(
    url: URL,
    serverName: String,
    userID: String,
    userName: String,
    apiToken: String,
    selectedLibraryId: String? = nil,
    customHeaders: [String: String] = [:]
  ) {
    self.url = url
    self.serverName = serverName
    self.userID = userID
    self.userName = userName
    self.apiToken = apiToken
    self.selectedLibraryId = selectedLibraryId
    self.customHeaders = customHeaders
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.url = try container.decode(URL.self, forKey: .url)
    self.serverName = try container.decode(String.self, forKey: .serverName)
    self.userID = try container.decode(String.self, forKey: .userID)
    self.userName = try container.decode(String.self, forKey: .userName)
    self.apiToken = try container.decode(String.self, forKey: .apiToken)
    self.selectedLibraryId = try container.decodeIfPresent(String.self, forKey: .selectedLibraryId)
    self.customHeaders = try container.decodeIfPresent([String: String].self, forKey: .customHeaders) ?? [:]
  }
}

extension AudiobookShelfConnectionData: CustomDebugStringConvertible {
  var debugDescription: String {
    let apiTokenDebugDesc = apiToken.isEmpty ? "<empty>" : "<redacted>"
    return "AudiobookShelfConnectionData(\(url), \(serverName), \(userID), \(userName), \(apiTokenDebugDesc))"
  }
}
