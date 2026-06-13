//
//  JellyfinConnectionData.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-20.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation

public struct JellyfinConnectionData: Codable, Identifiable {
  public let id: String
  public let serverId: String?
  public let url: URL
  public let serverName: String
  public let userID: String
  public let userName: String
  public let accessToken: String
  public var selectedLibraryId: String?
  public var customHeaders: [String: String] = [:]

  enum CodingKeys: String, CodingKey {
    case id, serverId, url, serverName, userID, userName, accessToken, selectedLibraryId, customHeaders
  }

  init(
    id: String = UUID().uuidString,
    serverId: String? = nil,
    url: URL,
    serverName: String,
    userID: String,
    userName: String,
    accessToken: String,
    selectedLibraryId: String? = nil,
    customHeaders: [String: String] = [:]
  ) {
    self.id = id
    self.serverId = serverId
    self.url = url
    self.serverName = serverName
    self.userID = userID
    self.userName = userName
    self.accessToken = accessToken
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
    self.accessToken = try container.decode(String.self, forKey: .accessToken)
    self.selectedLibraryId = try container.decodeIfPresent(String.self, forKey: .selectedLibraryId)
    self.customHeaders = try container.decodeIfPresent([String: String].self, forKey: .customHeaders) ?? [:]
  }
}

extension JellyfinConnectionData: CustomDebugStringConvertible {
  public var debugDescription: String {
    let accessTokenDebugDesc = accessToken.isEmpty ? "<empty>" : "<redacted>"
    let serverIdDesc = serverId ?? "<none>"
    return "JellyfinConnectionData(\(url), serverId: \(serverIdDesc), \(serverName), \(userID), \(userName), \(accessTokenDebugDesc))"
  }
  
  public func buildDownloadUrl(providerId: String) -> String {
    return "\(self.url.absoluteString)/items/\(providerId)/Download"
  }
}
