//
//  NetworkClient.swift
//  BookPlayer
//
//  Created by gianni.carlo on 23/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

public protocol NetworkClientProtocol {
  func request<T: Decodable>(
    path: String,
    method: HTTPMethod,
    parameters: [String: Any]?
  ) async throws -> T
}

public class NetworkClient: NetworkClientProtocol {
  let baseUrl = "https://api.tortugapower.com/v1"
  private let decoder: JSONDecoder = JSONDecoder()

  public init() {}

  public func request<T: Decodable>(
    path: String,
    method: HTTPMethod,
    parameters: [String: Any]?
  ) async throws -> T {
    let url = URL(string: baseUrl)!.appendingPathComponent(path)

    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    if let parameters = parameters {
      request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
    }

    let data = try await URLSession.shared.data(for: request)

    return try self.decoder.decode(T.self, from: data)
  }
}
