//
//  PartUploadTransport.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Combine
import Foundation

/// What happened to one part of a multipart upload
enum PartUploadEvent {
  case progress(partNumber: Int, bytesSent: Int64)
  /// `statusCode` is S3's answer; nil when the request never got one (`error` says why)
  case finished(partNumber: Int, statusCode: Int?, error: Error?)
}

/// Sends a multipart upload's parts. The background implementation hands them to iOS, so
/// they keep going while the app is suspended; the engine only needs this seam.
protocol PartUploadTransport: AnyObject {
  /// Parts of this S3 upload the system is still sending (or holding until it can)
  func activePartNumbers(for uuid: String, uploadId: String) async -> Set<Int>
  /// PUTs `file` to the part's presigned URL
  func startPart(uuid: String, uploadId: String, partNumber: Int, file: URL, url: URL)
  /// Every part of the book, whichever upload it belongs to
  func cancelParts(for uuid: String) async
  /// Delivers this S3 upload's part events until the returned subscription is cancelled.
  /// Events of the book's earlier uploads (cancelled by a restart) never arrive here.
  func subscribe(uuid: String, uploadId: String, handler: @escaping (PartUploadEvent) -> Void) -> AnyCancellable
}

/// `BPURLSession`'s two background sessions. Each part is its own upload task, described
/// `<uuid>#<partNumber>@<uploadId>` — the only link between a task and its upload, what
/// lets a relaunch find the parts still in flight, and what keeps a restarted upload from
/// reading its predecessor's late events.
final class BackgroundPartUploadTransport: PartUploadTransport {
  static let shared = BackgroundPartUploadTransport()

  private var sessions: [URLSession] {
    [BPURLSession.shared.backgroundSession, BPURLSession.shared.backgroundCellularSession]
  }

  static func taskDescription(uuid: String, partNumber: Int, uploadId: String) -> String {
    "\(uuid)#\(partNumber)@\(uploadId)"
  }

  /// nil for anything that isn't a part (e.g. a single-PUT upload from an older build).
  /// Split at the first `#` and the first `@` after it: uuids carry neither.
  static func parse(_ description: String?) -> (uuid: String, partNumber: Int, uploadId: String)? {
    guard
      let description,
      let hash = description.firstIndex(of: "#"),
      let at = description[hash...].firstIndex(of: "@"),
      let partNumber = Int(description[description.index(after: hash)..<at])
    else { return nil }
    return (String(description[..<hash]), partNumber, String(description[description.index(after: at)...]))
  }

  func activePartNumbers(for uuid: String, uploadId: String) async -> Set<Int> {
    var parts = Set<Int>()
    for session in sessions {
      for task in await session.allTasks where task.state == .running || task.state == .suspended {
        if let parsed = Self.parse(task.taskDescription), parsed.uuid == uuid, parsed.uploadId == uploadId {
          parts.insert(parsed.partNumber)
        }
      }
    }
    return parts
  }

  func startPart(uuid: String, uploadId: String, partNumber: Int, file: URL, url: URL) {
    let allowCellular = UserDefaults.standard.bool(forKey: Constants.UserDefaults.allowCellularData)
    let session = allowCellular
      ? BPURLSession.shared.backgroundCellularSession
      : BPURLSession.shared.backgroundSession
    // No auth header and no extra headers: the presigned signature covers `host` only
    var request = URLRequest(url: url)
    request.httpMethod = "PUT"
    request.cachePolicy = .reloadIgnoringLocalCacheData
    let task = session.uploadTask(with: request, fromFile: file)
    task.taskDescription = Self.taskDescription(uuid: uuid, partNumber: partNumber, uploadId: uploadId)
    task.resume()
  }

  func cancelParts(for uuid: String) async {
    for session in sessions {
      for task in await session.allTasks {
        if let parsed = Self.parse(task.taskDescription), parsed.uuid == uuid {
          task.cancel()
        }
      }
    }
  }

  func subscribe(uuid: String, uploadId: String, handler: @escaping (PartUploadEvent) -> Void) -> AnyCancellable {
    let belongs: (URLSessionTask) -> Int? = { task in
      guard let parsed = Self.parse(task.taskDescription),
            parsed.uuid == uuid,
            parsed.uploadId == uploadId
      else { return nil }
      return parsed.partNumber
    }
    let progress = BPURLSession.shared.progressPublisher
      .compactMap { task, bytesSent -> PartUploadEvent? in
        guard let partNumber = belongs(task) else { return nil }
        return .progress(partNumber: partNumber, bytesSent: bytesSent)
      }
    let completion = BPURLSession.shared.completionPublisher
      .compactMap { task, error -> PartUploadEvent? in
        guard let partNumber = belongs(task) else { return nil }
        // The background delegate doesn't surface HTTP failures as errors: S3's status
        // comes from the response
        let status = (task.response as? HTTPURLResponse)?.statusCode
        return .finished(partNumber: partNumber, statusCode: status, error: error)
      }
    return progress.merge(with: completion).sink(receiveValue: handler)
  }
}
