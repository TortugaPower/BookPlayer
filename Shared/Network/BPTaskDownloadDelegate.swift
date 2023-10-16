//
//  BPTaskDownloadDelegate.swift
//  BookPlayer
//
//  Created by gianni.carlo on 18/2/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation

public class BPTaskDownloadDelegate: NSObject, URLSessionDownloadDelegate {
  /// Callback triggered when the download task is finished
  public var didFinishDownloadingTask: ((URLSessionDownloadTask, URL) -> Void)?
  /// Callback triggered when the download task fails
  /// - Note: the Error parameter represents client side errors
  public var didFinishTaskWithError: ((URLSessionTask, Error?) -> Void)?
  /// Callback triggered when there's an update on the download progress
  public var downloadProgressUpdated: ((URLSessionDownloadTask, Double) -> Void)?
  /// Delegate callback when download finishes
  public func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    didFinishDownloadingTask?(downloadTask, location)
  }

  /// Note: this gets called even if there's no error
  public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    didFinishTaskWithError?(task, error)
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

    downloadProgressUpdated?(downloadTask, Double(calculatedProgress))
  }
}
