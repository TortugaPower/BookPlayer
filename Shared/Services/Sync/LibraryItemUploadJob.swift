//
//  LibraryItemUploadJob.swift
//  BookPlayer
//
//  Created by gianni.carlo on 23/6/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation
import SwiftQueue

struct LibraryItemUploadJob: Job {
  static let type = "LibraryItemUploadJob"

  let relativePath: String

  func onRun(callback: SwiftQueue.JobResult) {
    // Execute api call
    callback.done(.success)
  }

  func onRetry(error: Error) -> SwiftQueue.RetryConstraint {
    return .retry(delay: 3)
  }

  func onRemove(result: SwiftQueue.JobCompletion) {
    switch result {
    case .success:
      print("=== upload success for: \(self.relativePath)")
    case .fail(let error):
      print("=== upload error for: \(self.relativePath), error: \(error.localizedDescription)")
    }
  }
}

struct BookUploadJobCreator: JobCreator {
  func create(type: String, params: [String: Any]?) -> SwiftQueue.Job {
    guard
      type == LibraryItemUploadJob.type,
      let relativePath = params?["relativePath"] as? String
    else { fatalError("Wrong job to create") }

    return LibraryItemUploadJob(relativePath: relativePath)
  }
}
