//
//  MeData.swift
//  BookPlayer
//
//  Created by Pedro Iniguez on 10/31/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// Response model for `me`, the signed-in Hardcover user.
/// Hardcover answers it as a list with the one user; a single object is read the same way
struct MeData: Codable {
  let me: [User]

  struct User: Codable {
    let id: Int
    let username: String?
  }

  enum CodingKeys: String, CodingKey {
    case me
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    if let users = try? container.decode([User].self, forKey: .me) {
      self.me = users
    } else {
      self.me = [try container.decode(User.self, forKey: .me)]
    }
  }
}
