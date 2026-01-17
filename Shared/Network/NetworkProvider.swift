//
//  NetworkProvider.swift
//  BookPlayer
//
//  Created by gianni.carlo on 23/4/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import Foundation

public class NetworkProvider<RawEndpoint: Endpoint> {
  public let client: NetworkClientProtocol

  public init(client: NetworkClientProtocol = NetworkClient()) {
    self.client = client
  }

  public func request<T: Decodable>(
    _ endpoint: RawEndpoint
  ) async throws -> T {
    return try await self.client.request(
      path: endpoint.path,
      method: endpoint.method,
      parameters: endpoint.parameters
    )
  }
}
