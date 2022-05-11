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
  let scheme = "https"
  let host = "api.tortugapower.com"
  let keychain: KeychainServiceProtocol
  private let decoder: JSONDecoder = JSONDecoder()

  public init(keychain: KeychainServiceProtocol = KeychainService()) {
    self.keychain = keychain
  }

  public func request<T: Decodable>(
    path: String,
    method: HTTPMethod,
    parameters: [String: Any]?
  ) async throws -> T {
    let request = try buildURLRequest(path: path, method: method, parameters: parameters)

    let data = try await URLSession.shared.data(for: request)

    return try self.decoder.decode(T.self, from: data)
  }

  func buildURLRequest(
    path: String,
    method: HTTPMethod,
    parameters: [String: Any]?
  ) throws -> URLRequest {
    var components = URLComponents()
    components.scheme = scheme
    components.host = host
    components.path = path

    if case .get = method {
      if let parameters = parameters {
        let queryItems = parameters.map({
          URLQueryItem(
            name: $0.0,
            value: "\($0.1)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
          )
        })
        components.queryItems = queryItems
      }
    }

    guard let url = components.url else {
      throw URLError(.badURL)
    }

    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    if let accessToken = try? keychain.getAccessToken() {
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }

    if case .post = method,
       let parameters = parameters {
      request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
    }

    return request
  }
}
