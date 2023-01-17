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

  func upload(
    _ fileURL: URL,
    remoteURL: URL,
    identifier: String,
    method: HTTPMethod
  ) async throws -> (Data, URLResponse)
}

public class NetworkClient: NetworkClientProtocol, BPLogger {
  let scheme: String = Bundle.main.configurationValue(for: .apiScheme)
  let host: String = Bundle.main.configurationValue(for: .apiDomain)
  let port: String = Bundle.main.configurationValue(for: .apiPort)
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

    Self.logger.trace("[Request] \(method.rawValue) \(request.url?.path)\nParameters: \(parameters?.description)")

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpURLResponse = response as? HTTPURLResponse else {
      throw URLError(.badServerResponse)
    }

    Self.logger.trace("[Response] Status \(httpURLResponse.statusCode)\n\(String(data: data, encoding: .utf8))")

    switch httpURLResponse.statusCode {
    case 400...499:
      let error = try self.decoder.decode(ErrorResponse.self, from: data)
      throw BookPlayerError.networkError(error.message)
    default:
      return try self.decoder.decode(T.self, from: data)
    }
  }

  public func upload(
    _ fileURL: URL,
    remoteURL: URL,
    identifier: String,
    method: HTTPMethod
  ) async throws -> (Data, URLResponse) {
    var request = URLRequest(url: remoteURL)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.httpMethod = method.rawValue

    Self.logger.trace("[Request] \(method.rawValue) \(remoteURL.path)")

    let (responseData, response) = try await URLSession.shared.upload(
      for: request,
      fromFile: fileURL
    )

    if let httpResponse = response as? HTTPURLResponse {
      Self.logger.trace("[Response] Status \(httpResponse.statusCode) URL: \(response.url?.path)")
    }

    return (responseData, response)
  }

  func buildURLRequest(
    path: String,
    method: HTTPMethod,
    parameters: [String: Any]?
  ) throws -> URLRequest {
    var components = URLComponents()
    components.scheme = scheme
    components.host = host
    if let parsedPort = Int(port) {
      components.port = parsedPort
    }
    components.path = path

    if case .get = method,
       let parameters = parameters {
      let queryItems = parameters.map({
        URLQueryItem(
          name: $0.0,
          value: "\($0.1)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        )
      })
      components.queryItems = queryItems
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

    if let parameters = parameters {
      switch method {
      case .post, .put, .delete:
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
      case .get:
        break
      }
    }

    return request
  }
}

/// Default error message structure
struct ErrorResponse: Decodable {
  let message: String
}
