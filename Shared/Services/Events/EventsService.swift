//
//  EventsService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/7/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import Foundation

public protocol EventsServiceProtocol {
  func sendEvent(_ event: String, payload: [String: Any])
}

public class EventsService: EventsServiceProtocol, BPLogger {
  let client: NetworkClientProtocol
  private let provider: NetworkProvider<EventsAPI>

  public init(client: NetworkClientProtocol = NetworkClient()) {
    self.client = client
    self.provider = NetworkProvider(client: client)
  }

  public func sendEvent(_ event: String, payload: [String : Any]) {
    Task {
      do {
        let _: Empty = try await provider.request(.sendEvent(event: event, payload: payload))
      } catch {
        Self.logger.trace("Failed to send event \(event), error: \(error.localizedDescription)")
      }
    }
  }
}
