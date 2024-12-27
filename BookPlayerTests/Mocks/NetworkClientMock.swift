//
//  NetworkClientMock.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 23/4/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import Foundation
import BookPlayerKit

class NetworkClientMock: NetworkClientProtocol {
  func upload(_ data: Data, remoteURL: URL) async throws { }

  func uploadTask(
    _ fileURL: URL,
    remoteURL: URL,
    taskDescription: String?,
    session: URLSession
  ) async -> URLSessionTask {
    return session.uploadTask(with: URLRequest(url: URL(string: "https://google.com")!), from: Data())
  }

  typealias RawResponse = Decodable
  let mockedResponse: RawResponse

  init(mockedResponse: RawResponse) {
    self.mockedResponse = mockedResponse
  }

  func request<T: RawResponse>(
    url: URL,
    method: HTTPMethod,
    parameters: [String: Any]?,
    useKeychain: Bool
  ) async throws -> T {
    // swiftlint:disable:next force_cast
    return self.mockedResponse as! T
  }

  func request<T: RawResponse>(
    path: String,
    method: HTTPMethod,
    parameters: [String: Any]?
  ) async throws -> T {
    // swiftlint:disable:next force_cast
    return self.mockedResponse as! T
  }

  func upload(
    _ fileURL: URL,
    remoteURL: URL,
    identifier: String,
    method: HTTPMethod
  ) async throws -> (Data, URLResponse) {
    return (Data(), URLResponse())
  }

  func download(url: URL, delegate: BPTaskDownloadDelegate) {}

  func download(url: URL, taskDescription: String?, session: URLSession) async -> URLSessionTask {
    return URLSession.shared.downloadTask(with: URLRequest(url: URL(string: "https://google.com")!))
  }
}
