//
//  LibraryItemUploadJob.swift
//  BookPlayer
//
//  Created by gianni.carlo on 5/3/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation
import SwiftQueue

class LibraryItemUploadJob: Job, BPLogger {
  static let type = "LibraryItemUploadJob"

  let client: NetworkClientProtocol
  let provider: NetworkProvider<LibraryAPI>
  let relativePath: String
  let parameters: [String: Any]

  /// Initializer
  /// - Parameters:
  ///   - client: Network client
  ///   - parameters: Library item info in dictionary form
  init(
    client: NetworkClientProtocol,
    relativePath: String,
    parameters: [String: Any]
  ) {
    self.client = client
    self.provider = NetworkProvider(client: client)
    self.relativePath = relativePath
    self.parameters = parameters
  }

  func onRun(callback: SwiftQueue.JobResult) {
    Task { [weak self, callback] in
      guard let self = self else {
        callback.done(.fail(BookPlayerError.runtimeError("Deallocated self in LibraryItemUploadJob")))
        return
      }

      do {
        let response: UploadItemResponse = try await self.provider.request(.upload(params: self.parameters))

        guard let remoteURL = response.content.url else {
          /// The file is already present in the storage
          callback.done(.success)
          return
        }

        let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(self.relativePath)

        var isDirectory: ObjCBool = false

        guard
          FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory)
        else {
          /// Uploaded metadata will not have a backing file, but we'll have a backup of item data
          callback.done(.success)
          return
        }

        let isDirectoryBoolean = isDirectory.boolValue

        if isDirectoryBoolean {
          let _: Empty = try await self.client.request(
            url: remoteURL,
            method: .put,
            parameters: nil,
            useKeychain: false
          )
        } else {
          _ = try await self.client.upload(
            fileURL,
            remoteURL: remoteURL,
            identifier: self.relativePath,
            method: .put
          )
        }

        callback.done(.success)
      } catch {
        callback.done(.fail(error))
      }
    }
  }

  func onRetry(error: Error) -> SwiftQueue.RetryConstraint {
    return .retry(delay: 5)
  }

  func onRemove(result: SwiftQueue.JobCompletion) {
    switch result {
    case .success:
      Self.logger.trace("Finished upload for: \(self.relativePath)")
    case .fail(let error):
      Self.logger.error("Upload error for \(self.relativePath): \(error.localizedDescription)")
    }
  }
}

struct LibraryItemUploadJobCreator: JobCreator {
  func create(type: String, params: [String: Any]?) -> SwiftQueue.Job {
    guard
      type == LibraryItemUploadJob.type,
      let relativePath = params?["relativePath"] as? String,
      let parameters = params
    else { fatalError("Wrong job type") }

    return LibraryItemUploadJob(
      client: NetworkClient(),
      relativePath: relativePath,
      parameters: parameters
    )
  }
}
