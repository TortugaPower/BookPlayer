//
//  KeychainServiceMock.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 24/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation
import BookPlayerKit

class KeychainServiceMock: KeychainServiceProtocol {
  var accessToken: String?

  func setAccessToken(_ token: String) throws {
    accessToken = token
  }

  func getAccessToken() throws -> String? {
    return accessToken
  }

  func removeAccessToken() throws {
    accessToken = nil
  }
}
