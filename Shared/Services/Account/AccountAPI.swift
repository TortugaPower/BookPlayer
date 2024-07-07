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
  case secondOnboarding(anonymousId: String, firstSeen: Double, region: String)
}

extension AccountAPI: Endpoint {
  public var path: String {
    switch self {
    case .login:
      return "/v1/user/login"
    case .delete:
      return "/v1/user/delete"
    case .secondOnboarding:
      return "/v1/user/second_onboarding"
    }
  }

  public var method: HTTPMethod {
    switch self {
    case .login:
      return .post
    case .delete:
      return .delete
    case .secondOnboarding:
      return .post
    }
  }

  public var parameters: [String: Any]? {
    switch self {
    case .login(let token):
      return ["token_id": token]
    case .delete:
      return nil
    case .secondOnboarding(let anonymousId, let firstSeen, let region):
      return [
        "rc_id": anonymousId,
        "first_seen": firstSeen,
        "region": region
      ]
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
