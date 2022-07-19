//
//  LibraryItemFileUploadJob.swift
//  BookPlayer
//
//  Created by gianni.carlo on 10/7/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation
import SwiftQueue

class LibraryItemFileUploadJob: NSObject, Job, BPLogger {
  static let type = "LibraryItemFileUploadJob"

  let client: NetworkClientProtocol
  let relativePath: String
  let remoteURL: URL
  var response: UploadItemResponse?

  /// Initializer
  /// - Parameters:
  ///   - client: Network client
  ///   - relativePath: Local file relative path to upload
  ///   - remoteURL: Signed URL to upload to
  ///   - response: Used for testing purposes in this initializer
  init(
    client: NetworkClientProtocol,
    relativePath: String,
    remoteURL: URL,
    response: UploadItemResponse? = nil
  ) {
    self.client = client
    self.relativePath = relativePath
    self.remoteURL = remoteURL
    self.response = response
  }

  func onRun(callback: SwiftQueue.JobResult) {
    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(self.relativePath)

    var isDirectory: ObjCBool = false

    guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) else {
      callback.done(.fail(BookPlayerError.runtimeError("Item file not found")))
      return
    }

    guard !isDirectory.boolValue else {
      callback.done(.fail(BookPlayerError.runtimeError("File url is for a directory")))
      return
    }

    Task { [weak self, callback, fileURL] in
      guard let self = self else {
        callback.done(.fail(BookPlayerError.runtimeError("Deallocated self in LibraryItemFileUploadJob")))
        return
      }

      do {
        _ = try await self.client.upload(
          fileURL,
          remoteURL: self.remoteURL,
          identifier: self.relativePath,
          method: .put
        )

        callback.done(.success)
      } catch {
        callback.done(.fail(error))
      }
    }
  }

  func onRetry(error: Error) -> SwiftQueue.RetryConstraint {
    return .retry(delay: 3)
  }

  func onRemove(result: SwiftQueue.JobCompletion) {
    switch result {
    case .success:
      // Store synced status in CoreData
      break
    case .fail(let error):
      Self.logger.error("Upload error for \(self.relativePath): \(error.localizedDescription)")
    }
  }
}

struct LibraryItemFileUploadJobCreator: JobCreator {
  func create(type: String, params: [String: Any]?) -> SwiftQueue.Job {
    guard
      type == LibraryItemFileUploadJob.type,
      let relativePath = params?["relativePath"] as? String,
      let remoteUrlPath = params?["remoteUrlPath"] as? String,
      let remoteURL = URL(string: remoteUrlPath)
    else { fatalError("Wrong job type") }

    return LibraryItemFileUploadJob(
      client: NetworkClient(),
      relativePath: relativePath,
      remoteURL: remoteURL
    )
  }
}
