//
//  SyncResponseFixtures.swift
//  BookPlayerTests
//
//  Builders for server sync payloads. Every fixture round-trips raw JSON through
//  the real decoder (the same pattern as `makeServerResponse` in
//  PreferencesSyncServiceTests) so tests stay honest about the wire format —
//  including quirks like a missing `orderRank` decoding to 0.
//

@testable import BookPlayerKit
import Foundation

enum SyncResponseFixtures {
  enum FixtureError: Error {
    case notJSONCompatible
  }

  /// Raw JSON for one `/v1/library` content entry. Pass `orderRank: nil` to omit
  /// the field entirely (exercises the `?? 0` decode default).
  static func itemJSON(
    relativePath: String,
    title: String? = nil,
    originalFileName: String? = nil,
    orderRank: Int? = 0,
    type: SimpleItemType = .book,
    isFinished: Bool = false,
    duration: Double = 100,
    currentTime: Double = 0,
    percentCompleted: Double = 0,
    speed: Double? = nil,
    lastPlayDateTimestamp: Double? = nil,
    uuid: String? = nil,
    details: String = "fixture-author"
  ) -> [String: Any] {
    var json: [String: Any] = [
      "relativePath": relativePath,
      "originalFileName": originalFileName ?? (relativePath as NSString).lastPathComponent,
      "title": title ?? relativePath,
      "isFinished": isFinished,
      "type": Int(type.rawValue),
      "duration": duration,
      "currentTime": currentTime,
      "percentCompleted": percentCompleted,
      "details": details,
      "uuid": uuid ?? UUID().uuidString,
    ]
    if let orderRank {
      json["orderRank"] = orderRank
    }
    if let speed {
      json["speed"] = speed
    }
    if let lastPlayDateTimestamp {
      json["lastPlayDateTimestamp"] = lastPlayDateTimestamp
    }
    return json
  }

  static func makeSyncableItem(_ json: [String: Any]) throws -> SyncableItem {
    return try decode(json)
  }

  /// Items keyed by relativePath — the shape `updateInfo(for:parentFolder:)` and
  /// `storeNewItems(from:parentFolder:)` consume (see `processContentsResponse`).
  static func makeItemsDictionary(_ jsons: [[String: Any]]) throws -> [String: SyncableItem] {
    let items: [SyncableItem] = try jsons.map { try decode($0) }
    return Dictionary(items.map { ($0.relativePath, $0) }) { first, _ in first }
  }

  static func makeContentsResponse(
    content: [[String: Any]],
    lastItemPlayed: [String: Any]? = nil
  ) throws -> ContentsResponse {
    var json: [String: Any] = ["content": content]
    if let lastItemPlayed {
      json["lastItemPlayed"] = lastItemPlayed
    }
    return try decode(json)
  }

  private static func decode<T: Decodable>(_ object: Any) throws -> T {
    guard JSONSerialization.isValidJSONObject(object) else {
      throw FixtureError.notJSONCompatible
    }
    let data = try JSONSerialization.data(withJSONObject: object)
    return try JSONDecoder().decode(T.self, from: data)
  }
}
