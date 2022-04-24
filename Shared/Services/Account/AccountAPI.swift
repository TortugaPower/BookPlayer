//
//  AccountAPI.swift
//  BookPlayer
//
//  Created by gianni.carlo on 23/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

public enum AccountAPI {
  case login(token: String)
}

extension AccountAPI: Endpoint {
  public var path: String {
    switch self {
    case .login:
      return "user/login"
    }
  }

  public var method: HTTPMethod {
    switch self {
    case .login:
      return .post
    }
  }

  public var parameters: [String: Any]? {
    switch self {
    case .login(let token):
      return ["token_id": token]
    }
  }

}

struct LoginResponse: Decodable {
  let email: String
  let token: String
}
