//
//  LibraryItemSyncJob.swift
//  BookPlayer
//
//  Created by gianni.carlo on 5/3/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation
import SwiftQueue

enum JobType: String {
  case upload
  case update
  case move
  case delete
  case shallowDelete
  case setBookmark
  case deleteBookmark

  var identifier: String {
    return "BKPLY-\(self.rawValue)"
  }
}

class LibraryItemSyncJob: Job, BPLogger {
  static let type = "LibraryItemSyncJob"

  let client: NetworkClientProtocol
  let provider: NetworkProvider<LibraryAPI>
  let relativePath: String
  let jobType: JobType
  let parameters: [String: Any]

  /// Initializer
  /// - Parameters:
  ///   - client: Network client
  ///   - parameters: Library item info in dictionary form
  init(
    client: NetworkClientProtocol,
    relativePath: String,
    jobType: JobType,
    parameters: [String: Any]
  ) {
    self.client = client
    self.provider = NetworkProvider(client: client)
    self.relativePath = relativePath
    self.jobType = jobType
    self.parameters = parameters
  }

  func onRun(callback: SwiftQueue.JobResult) {
    Task { [weak self, callback] in
      guard let self = self else {
        callback.done(.fail(BookPlayerError.runtimeError("Deallocated self in LibraryItemUploadJob")))
        return
      }

      do {
        switch self.jobType {
        case .upload:
          guard
            let rawType = parameters["type"] as? Int16,
            let type = SimpleItemType(rawValue: rawType)
          else {
            throw BookPlayerError.runtimeError("Missing parameters for uploading")
          }
          try await self.handleUploadJob(
            type: type,
            callback: callback
          )
        case .update:
          let _: UploadItemResponse = try await self.provider.request(.update(params: self.parameters))
          callback.done(.success)
        case .move:
          guard
            let origin = parameters["origin"] as? String,
            let destination = parameters["destination"] as? String
          else {
            throw BookPlayerError.runtimeError("Missing parameters for moving")
          }
          let _: Empty = try await self.provider.request(.move(origin: origin, destination: destination))
          callback.done(.success)
        case .delete:
          let _: Empty = try await provider.request(.delete(path: self.relativePath))
          callback.done(.success)
        case .shallowDelete:
          let _: Empty = try await provider.request(.shallowDelete(path: self.relativePath))
          callback.done(.success)
        case .setBookmark:
          try await handleSetBookmark()
          callback.done(.success)
        case .deleteBookmark:
          try await handleDeleteBookmark()
          callback.done(.success)
        }
      } catch {
        callback.done(.fail(error))
      }
    }
  }

  func handleSetBookmark() async throws {
    guard
      let time = parameters["time"] as? Double
    else {
      throw BookPlayerError.runtimeError("Missing parameters for creating a bookmark")
    }

    let _: Empty = try await provider.request(
      .setBookmark(
        path: self.relativePath,
        note: parameters["note"] as? String,
        time: time,
        isActive: true
      )
    )
  }

  func handleDeleteBookmark() async throws {
    guard
      let time = parameters["time"] as? Double
    else {
      throw BookPlayerError.runtimeError("Missing parameters for deleting a bookmark")
    }

    let _: Empty = try await provider.request(
      .setBookmark(
        path: self.relativePath,
        note: nil,
        time: time,
        isActive: false
      )
    )
  }

  func handleUploadJob(
    type: SimpleItemType,
    callback: SwiftQueue.JobResult
  ) async throws {
    let response: UploadItemResponse = try await self.provider.request(.upload(params: self.parameters))

    guard let remoteURL = response.content.url else {
      /// The file is already present in the storage
      callback.done(.success)
      return
    }

    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(self.relativePath)

    guard
      FileManager.default.fileExists(atPath: fileURL.path)
    else {
      /// Uploaded metadata will not have a backing file, but we'll have a backup of item data
      callback.done(.success)
      return
    }

    guard type == .book else {
      let _: Empty = try await self.client.request(
        url: remoteURL,
        method: .put,
        parameters: nil,
        useKeychain: false
      )

      /// Clean up hard link
      try FileManager.default.removeItem(at: fileURL)
      callback.done(.success)
      return
    }

    uploadFile(
      fileURL: fileURL,
      remoteURL: remoteURL,
      relativePath: self.relativePath
    )
  }

  /// Upload file on a background thread, the callback can't be used,
  /// so it's up to the queue manager to remove the job once it's done
  func uploadFile(
    fileURL: URL,
    remoteURL: URL,
    relativePath: String
  ) {
    let uploadDelegate = BPTaskUploadDelegate()
    uploadDelegate.uploadProgressUpdated = { task, uploadProgress in
      guard let relativePath = task.taskDescription else { return }

      NotificationCenter.default.post(
        name: .uploadProgressUpdated,
        object: nil,
        userInfo: [
          "progress": uploadProgress,
          "relativePath": relativePath
        ]
      )
    }

    uploadDelegate.didFinishTask = { task, error in
      if task.state == .completed && error == nil {
        NotificationCenter.default.post(name: .uploadCompleted, object: task)
      } else {
        /// Got an error, and the queue can get stuck, better to recreate it
        NotificationCenter.default.post(name: .recreateQueue, object: task)
      }
    }

    _ = self.client.upload(
      fileURL,
      remoteURL: remoteURL,
      taskDescription: relativePath,
      delegate: uploadDelegate
    )
  }

  func onRetry(error: Error) -> SwiftQueue.RetryConstraint {
    return .retry(delay: 5)
  }

  func onRemove(result: SwiftQueue.JobCompletion) {
    switch result {
    case .success:
      Self.logger.trace("Finished \(self.jobType.rawValue) for: \(self.relativePath)")
    case .fail(let error):
      Self.logger.error("Error on jobType \(self.jobType.rawValue) for \(self.relativePath): \(error.localizedDescription)")
    }
  }
}

struct LibraryItemUploadJobCreator: JobCreator {
  func create(type: String, params: [String: Any]?) -> SwiftQueue.Job {
    guard
      type == LibraryItemSyncJob.type,
      let relativePath = params?["relativePath"] as? String,
      let jobTypeRaw = params?["jobType"] as? String,
      let jobType = JobType(rawValue: jobTypeRaw)
    else { fatalError("Wrong job type") }

    return LibraryItemSyncJob(
      client: NetworkClient(),
      relativePath: relativePath,
      jobType: jobType,
      parameters: params ?? [:]
    )
  }
}
