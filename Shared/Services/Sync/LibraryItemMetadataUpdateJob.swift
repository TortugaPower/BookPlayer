//
//  LibraryItemMetadataUpdateJob.swift
//  BookPlayer
//
//  Created by gianni.carlo on 9/2/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation
import SwiftQueue

class LibraryItemMetadataUpdateJob: Job, BPLogger {
  static let type = "LibraryItemMetadataUpdateJob"

  let client: NetworkClientProtocol
  let provider: NetworkProvider<LibraryAPI>
  let parameters: [String: Any]
  var response: UploadItemResponse?

  lazy var taskIdentifier: String? = {
    return self.parameters["relativePath"] as? String
  }()

  /// Initializer
  /// - Parameters:
  ///   - client: Network client
  ///   - parameters: Library item info in dictionary form
  ///   - response: Used for testing purposes in this initializer
  init(
    client: NetworkClientProtocol,
    parameters: [String: Any],
    response: UploadItemResponse? = nil
  ) {
    self.client = client
    self.provider = NetworkProvider(client: client)
    self.parameters = parameters
    self.response = response
  }

  func onRun(callback: SwiftQueue.JobResult) {
    Task { [weak self, callback] in
      guard let self = self else {
        callback.done(.fail(BookPlayerError.runtimeError("Deallocated self in LibraryItemMetadataUpdateJob")))
        return
      }

      do {
        self.response = try await self.provider.request(.upload(params: self.parameters))

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
      Self.logger.log("Success updating metadata for \(self.taskIdentifier)")
    case .fail(let error):
      Self.logger.error("Upload error for \(self.taskIdentifier): \(error.localizedDescription)")
    }
  }
}

struct LibraryItemMetadataUpdateJobCreator: JobCreator {
  func create(type: String, params: [String: Any]?) -> SwiftQueue.Job {
    guard
      type == LibraryItemMetadataUpdateJob.type,
      let parameters = params
    else { fatalError("Wrong job type") }

    return LibraryItemMetadataUpdateJob(
      client: NetworkClient(),
      parameters: parameters
    )
  }
}
