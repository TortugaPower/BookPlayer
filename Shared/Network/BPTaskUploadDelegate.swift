//
//  BPTaskUploadDelegate.swift
//  BookPlayer
//
//  Created by gianni.carlo on 7/3/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import Foundation

class BPTaskUploadDelegate: NSObject, URLSessionTaskDelegate {
  /// Callback triggered when there's an update on the upload progress, with the task's
  /// bytes sent so far (a multipart upload sums them across its parts)
  var uploadProgressUpdated: ((URLSessionTask, Int64) -> Void)?
  /// Callback triggered when the download task is finished
  var didFinishTask: ((URLSessionTask, Error?) -> Void)?

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didSendBodyData bytesSent: Int64,
    totalBytesSent: Int64,
    totalBytesExpectedToSend: Int64
  ) {
    uploadProgressUpdated?(task, totalBytesSent)
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    didFinishTask?(task, error)
  }
}
