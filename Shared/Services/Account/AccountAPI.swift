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
  case delete
}

extension AccountAPI: Endpoint {
  public var path: String {
    switch self {
    case .login:
      return "/v1/user/login"
    case .delete:
      return "/v1/user/delete"
    }
  }

  public var method: HTTPMethod {
    switch self {
    case .login:
      return .post
    case .delete:
      return .delete
    }
  }

  public var parameters: [String: Any]? {
    switch self {
    case .login(let token):
      return ["token_id": token]
    case .delete:
      return nil
    }
  }
}

struct LoginResponse: Decodable {
  let email: String
  let token: String
}

struct DeleteResponse: Decodable {
  let message: String
}
