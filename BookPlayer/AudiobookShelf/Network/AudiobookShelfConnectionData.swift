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
}

extension AudiobookShelfConnectionData: CustomDebugStringConvertible {
  var debugDescription: String {
    let apiTokenDebugDesc = apiToken.isEmpty ? "<empty>" : "<redacted>"
    return "AudiobookShelfConnectionData(\(url), \(serverName), \(userID), \(userName), \(apiTokenDebugDesc))"
  }
}
