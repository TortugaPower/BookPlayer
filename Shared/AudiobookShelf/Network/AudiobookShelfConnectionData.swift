//
//  AudiobookShelfConnectionData.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 14/11/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

public struct AudiobookShelfConnectionData: Codable, Identifiable {
  public let id: String
  public let serverId: String?
  public let url: URL
  public let serverName: String
  public let userID: String
  public let userName: String
  public let apiToken: String
  public var selectedLibraryId: String?
  public var customHeaders: [String: String] = [:]

  public enum CodingKeys: String, CodingKey {
    case id, serverId, url, serverName, userID, userName, apiToken, selectedLibraryId, customHeaders
  }

  public init(
    id: String = UUID().uuidString,
    serverId: String? = nil,
    url: URL,
    serverName: String,
    userID: String,
    userName: String,
    apiToken: String,
    selectedLibraryId: String? = nil,
    customHeaders: [String: String] = [:]
  ) {
    self.id = id
    self.serverId = serverId
    self.url = url
    self.serverName = serverName
    self.userID = userID
    self.userName = userName
    self.apiToken = apiToken
    self.selectedLibraryId = selectedLibraryId
    self.customHeaders = customHeaders
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
    self.serverId = try? container.decodeIfPresent(String.self, forKey: .serverId)
    self.url = try container.decode(URL.self, forKey: .url)
    self.serverName = try container.decode(String.self, forKey: .serverName)
    self.userID = try container.decode(String.self, forKey: .userID)
    self.userName = try container.decode(String.self, forKey: .userName)
    self.apiToken = try container.decode(String.self, forKey: .apiToken)
    self.selectedLibraryId = try container.decodeIfPresent(String.self, forKey: .selectedLibraryId)
    self.customHeaders = try container.decodeIfPresent([String: String].self, forKey: .customHeaders) ?? [:]
  }
}

extension AudiobookShelfConnectionData: IntegrationConnectionPayload {
  /// Computed on purpose — see `IntegrationConnectionPayload`. Renaming or adding a stored property
  /// here would change the `Codable` shape and stop existing Keychain records from decoding.
  var token: String { apiToken }
}

extension AudiobookShelfConnectionData: CustomDebugStringConvertible {
  public var debugDescription: String {
    let apiTokenDebugDesc = apiToken.isEmpty ? "<empty>" : "<redacted>"
    let serverIdDesc = serverId ?? "<none>"
    return "AudiobookShelfConnectionData(\(url), serverId: \(serverIdDesc), \(serverName), \(userID), \(userName), \(apiTokenDebugDesc))"
  }
  
  public func buildAudiobookshelfDownloadUrl(providerId: String) -> String {
    return "\(self.url.absoluteString)/api/items/\(providerId)/download"
  }
}
