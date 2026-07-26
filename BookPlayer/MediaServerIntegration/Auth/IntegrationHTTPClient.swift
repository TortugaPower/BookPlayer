//
//  IntegrationHTTPClient.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 25/7/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// The HTTP surface the integration auth flows need, behind a protocol so those flows can be driven
/// in tests without a network or a server.
protocol IntegrationHTTPClient {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)

  /// Issues `request` **without following redirects** and returns the URL it was redirected to.
  ///
  /// AudiobookShelf's OIDC handshake depends on this. The app has to make the `/auth/openid` request
  /// itself so the `connect.sid` session cookie ABS sets on that response lands in *this* client's
  /// cookie jar — the later token exchange is validated against that session. Letting the browser
  /// make the request instead strands the cookie in Safari's store, and the exchange then fails with
  /// `No session`.
  func redirectLocation(for request: URLRequest) async throws -> URL
}

/// `URLSession`-backed client. Deliberately one long-lived session, so cookies set by one call are
/// present on the next — the OIDC exchange depends on exactly that.
final class IntegrationURLSessionClient: IntegrationHTTPClient {
  private let session: URLSession

  init(timeout: TimeInterval = 15) {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = timeout
    // Spelled out rather than left to the defaults, because the OIDC flow's correctness rests on it.
    configuration.httpCookieAcceptPolicy = .always
    configuration.httpShouldSetCookies = true
    self.session = URLSession(configuration: configuration)
  }

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw IntegrationError.unexpectedResponse(code: nil)
    }
    return (data, http)
  }

  func redirectLocation(for request: URLRequest) async throws -> URL {
    let (data, response) = try await session.data(for: request, delegate: RedirectBlocker())
    guard let http = response as? HTTPURLResponse else {
      throw IntegrationError.unexpectedResponse(code: nil)
    }

    guard (300...399).contains(http.statusCode) else {
      // Non-redirect here means the server refused to start the handshake. Its body carries the
      // actual reason (AudiobookShelf answers `Invalid redirect_uri` in plain text), so surface it
      // rather than reducing everything to a bare status code.
      throw IntegrationError.from(status: http.statusCode, body: data)
    }

    guard
      let location = http.value(forHTTPHeaderField: "Location"),
      let url = URL(string: location, relativeTo: request.url)?.absoluteURL
    else {
      throw IntegrationError.unexpectedResponse(code: http.statusCode)
    }
    return url
  }

}

/// Per-task delegate that declines redirects, so the caller can inspect the 3xx itself.
private final class RedirectBlocker: NSObject, URLSessionTaskDelegate {
  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest
  ) async -> URLRequest? {
    nil
  }
}
