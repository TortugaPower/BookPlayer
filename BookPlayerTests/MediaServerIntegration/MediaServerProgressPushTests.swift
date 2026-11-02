//
//  MediaServerProgressPushTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayerKit
import XCTest

/// A progress push carries when the position was reached (the book's `lastPlayDate`), as the Android
/// app's does: Jellyfin stores a date only when a client sends one, and AudiobookShelf otherwise records
/// the moment the push landed.
final class ExternalUpdateLastPlayedDateTests: XCTestCase {
  func testTheTaskTimestampBecomesTheDate() {
    XCTAssertEqual(
      ExternalUpdateProgressOperation.lastPlayedDate(fromTimestamp: 1_790_000_000.5),
      Date(timeIntervalSince1970: 1_790_000_000.5)
    )
  }

  /// The timestamp is persisted with the task, so a value no date has must be dropped, not converted:
  /// the AudiobookShelf push turns it into an integer, which traps on NaN or infinity on every pop.
  func testValuesNoRealDateHasAreLeftOut() {
    for timestamp in [nil, .nan, .infinity, -.infinity, -1, 1e12] as [Double?] {
      XCTAssertNil(
        ExternalUpdateProgressOperation.lastPlayedDate(fromTimestamp: timestamp),
        "\(String(describing: timestamp))"
      )
    }
  }
}

@MainActor
final class AudiobookShelfProgressPushTests: XCTestCase {
  private var http: ProgressHTTPStub!
  private var service: AudiobookShelfConnectionService!

  override func setUp() {
    super.setUp()
    http = ProgressHTTPStub()
    service = AudiobookShelfConnectionService(keychainService: KeychainServiceMock(), httpClient: http)
    service.useConnection(
      AudiobookShelfConnectionData(
        url: URL(string: "https://abs.example.com")!,
        serverName: "ABS",
        userID: "u1",
        userName: "reader",
        apiToken: "t"
      )
    )
  }

  override func tearDown() {
    http = nil
    service = nil
    super.tearDown()
  }

  private func sentBody() throws -> [String: Any] {
    let request = try XCTUnwrap(http.requests.first)
    XCTAssertEqual(request.httpMethod, "PATCH")
    XCTAssertEqual(request.url?.path, "/api/me/progress/li_1")
    let body = try XCTUnwrap(request.httpBody)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
  }

  func testThePushSendsWhenThePositionWasReachedInMilliseconds() async throws {
    try await service.updateProgress(
      for: "li_1",
      progress: 0.5,
      currentTime: 120,
      lastUpdate: Date(timeIntervalSince1970: 1_790_000_000.123)
    )

    let body = try sentBody()
    XCTAssertEqual(body["lastUpdate"] as? Int64, 1_790_000_000_123)
    XCTAssertEqual(body["progress"] as? Double, 0.5)
    XCTAssertEqual(body["currentTime"] as? Double, 120)
  }

  /// Without a date the key is left out, so the server stamps the push itself rather than reading a null.
  func testAPushWithoutADateLeavesTheKeyOut() async throws {
    try await service.updateProgress(for: "li_1", progress: 0.5, currentTime: 120, lastUpdate: nil)

    let body = try sentBody()
    XCTAssertNil(body["lastUpdate"])
    XCTAssertEqual(body["progress"] as? Double, 0.5)
  }
}

/// `@unchecked Sendable`: a test double read from one task at a time.
private final class ProgressHTTPStub: IntegrationHTTPClient, @unchecked Sendable {
  private(set) var requests = [URLRequest]()

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    requests.append(request)
    return (Data(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
  }

  func redirectLocation(for request: URLRequest) async throws -> URL {
    throw URLError(.unsupportedURL)
  }
}
