//
//  BPTaskDownloadDelegate.swift
//  BookPlayer
//
//  Created by gianni.carlo on 18/2/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import Foundation

public class BPTaskDownloadDelegate: NSObject, URLSessionDownloadDelegate {
  /// Callback triggered when the download task is finished
  public var didFinishDownloadingTask: ((URLSessionTask, URL?, Error?) -> Void)?
  /// Callback triggered when there's an update on the download progress
  public var downloadProgressUpdated: ((URLSessionDownloadTask, Double) -> Void)?
  /// Callback triggered when the total size of the download is unknown,
  /// and we can't compute a progress percentage
  public var downloadBytesWrittenUpdated: ((URLSessionDownloadTask, Int64) -> Void)?
  /// Delegate callback when download finishes
  public func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    didFinishDownloadingTask?(
      downloadTask,
      location,
      parseErrorFromTask(downloadTask)
    )
  }

  /// Note: this gets called even if there's no error
  public func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    let error = error ?? parseErrorFromTask(task)
    didFinishDownloadingTask?(task, nil, error)
  }

  /// Delegate callback when there's a progress update for the ongoing download
  public func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    let calculatedProgress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)

    if totalBytesExpectedToWrite == -1 {
      downloadBytesWrittenUpdated?(downloadTask, totalBytesWritten)
    } else {
      downloadProgressUpdated?(downloadTask, Double(calculatedProgress))
    }
  }

  private func parseErrorFromTask(_ task: URLSessionTask) -> Error? {
    guard
      let response = task.response as? HTTPURLResponse,
      response.statusCode >= 400
    else {
      return nil
    }

    let errorCode = URLError.Code(rawValue: response.statusCode)
    return URLError(errorCode)
  }
}
