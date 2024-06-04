//
//  EventsAPI.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/7/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import Foundation

public enum EventsAPI {
  case sendEvent(event: String, payload: [String: Any])
}

extension EventsAPI: Endpoint {
  public var path: String {
    switch self {
    case .sendEvent:
      return "/v1/user/events"
    }
  }

  public var method: HTTPMethod {
    switch self {
    case .sendEvent:
      return .post
    }
  }

  public var parameters: [String: Any]? {
    switch self {
    case .sendEvent(let event, let payload):
      return ["event": event, "event_data": payload]
    }
  }
}
