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
    url: URL,
    method: HTTPMethod,
    parameters: [String: Any]?,
    useKeychain: Bool
  ) async throws -> T

  func request<T: Decodable>(
    path: String,
    method: HTTPMethod,
    parameters: [String: Any]?
  ) async throws -> T

  func upload(
    _ data: Data,
    remoteURL: URL
  ) async throws

  func upload(
    _ fileURL: URL,
    remoteURL: URL,
    taskDescription: String?,
    delegate: URLSessionTaskDelegate
  ) async -> URLSessionTask

  func download(
    url: URL,
    taskDescription: String?,
    delegate: URLSessionTaskDelegate
  ) -> URLSessionDownloadTask
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
    url: URL,
    method: HTTPMethod,
    parameters: [String: Any]?,
    useKeychain: Bool
  ) async throws -> T {
    let request = try buildURLRequest(
      url: url,
      method: method,
      parameters: parameters,
      useKeychain: useKeychain
    )

    return try await executeRequest(request, method: method, parameters: parameters)
  }

  public func request<T: Decodable>(
    path: String,
    method: HTTPMethod,
    parameters: [String: Any]?
  ) async throws -> T {
    let request = try buildURLRequest(path: path, method: method, parameters: parameters)

    return try await executeRequest(request, method: method, parameters: parameters)
  }

  public func download(
    url: URL,
    taskDescription: String?,
    delegate: URLSessionTaskDelegate
  ) -> URLSessionDownloadTask {
    let bundleIdentifier: String = Bundle.main.configurationValue(for: .bundleIdentifier)

    let session = URLSession(
      configuration: URLSessionConfiguration.background(
        withIdentifier: "\(bundleIdentifier).background.download"
      ),
      delegate: delegate,
      delegateQueue: OperationQueue()
    )

    let task = session.downloadTask(with: url)
    task.taskDescription = taskDescription
    task.resume()

    return task
  }

  public func upload(
    _ data: Data,
    remoteURL: URL
  ) async throws {
    var request = URLRequest(url: remoteURL)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.httpMethod = HTTPMethod.put.rawValue

    Self.logger.trace("[Request] PUT \(remoteURL.path)")

    _ = try await URLSession.shared.upload(for: request, from: data)
  }

  public func upload(
    _ fileURL: URL,
    remoteURL: URL,
    taskDescription: String?,
    delegate: URLSessionTaskDelegate
  ) async -> URLSessionTask {
    var request = URLRequest(url: remoteURL)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.httpMethod = HTTPMethod.put.rawValue

    let bundleIdentifier: String = Bundle.main.configurationValue(for: .bundleIdentifier)

    let session = URLSession(
      configuration: URLSessionConfiguration.background(
        withIdentifier: "\(bundleIdentifier).background"
      ),
      delegate: delegate,
      delegateQueue: OperationQueue()
    )

    let allTasks = await session.allTasks

    /// Avoid creating a new task if one exists already to avoid double uploads
    if let existingTask = allTasks.first(where: { task in
      task.taskDescription == taskDescription
    }) {
      Self.logger.trace("Existing request for: \(remoteURL.path)")
      return existingTask
    } else {
      Self.logger.trace("[Request] PUT \(remoteURL.path)")

      let task = session.uploadTask(with: request, fromFile: fileURL)
      task.taskDescription = taskDescription
      task.resume()

      return task
    }
  }

  func executeRequest<T: Decodable>(
    _ request: URLRequest,
    method: HTTPMethod,
    parameters: [String: Any]?
  ) async throws -> T {

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
      guard !data.isEmpty else {
        guard
          let emptyResponseType = T.self as? EmptyResponse.Type,
          let emptyValue = emptyResponseType.emptyValue() as? T
        else {
          throw URLError(.cannotParseResponse)
        }

        return emptyValue
      }

      return try self.decoder.decode(T.self, from: data)
    }
  }

  func buildURLRequest(
    url: URL,
    method: HTTPMethod,
    parameters: [String: Any]?,
    useKeychain: Bool = true
  ) throws -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    if useKeychain,
      let accessToken = try? keychain.getAccessToken() {
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
          value: "\($0.1)"
        )
      })
      components.queryItems = queryItems
    }

    guard let url = components.url else {
      throw URLError(.badURL)
    }

    return try buildURLRequest(url: url, method: method, parameters: parameters)
  }
}

/// Default error message structure
struct ErrorResponse: Decodable {
  let message: String
}
