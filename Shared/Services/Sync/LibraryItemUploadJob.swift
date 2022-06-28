//
//  LibraryItemUploadJob.swift
//  BookPlayer
//
//  Created by gianni.carlo on 23/6/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation
import SwiftQueue

class LibraryItemUploadJob: Job {
  static let type = "LibraryItemUploadJob"

  let client: NetworkClientProtocol
  let provider: NetworkProvider<LibraryAPI>
  let parameters: [String: Any]
  var response: UploadItemResponse?

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
        callback.done(.fail(BookPlayerError.runtimeError("Deallocated self in LibraryItemUploadJob")))
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
      print("=== upload success for: \(parameters["relativePath"]!)")
      if let response = self.response {
        // Notify for file upload with response
        print(response)
      }
    case .fail(let error):
      print("=== upload error for: \(parameters["relativePath"]!), error: \(error.localizedDescription)")
    }
  }
}

struct LibraryItemUploadJobCreator: JobCreator {
  func create(type: String, params: [String: Any]?) -> SwiftQueue.Job {
    guard
      type == LibraryItemUploadJob.type,
      let parameters = params
    else { fatalError("Wrong job type") }

    return LibraryItemUploadJob(
      client: NetworkClient(),
      parameters: parameters
    )
  }
}
