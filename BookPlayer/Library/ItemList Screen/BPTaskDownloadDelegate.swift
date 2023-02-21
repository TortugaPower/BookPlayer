//
//  BPTaskDownloadDelegate.swift
//  BookPlayer
//
//  Created by gianni.carlo on 18/2/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import AVFoundation
import Foundation

class BPTaskDownloadDelegate: NSObject, URLSessionDownloadDelegate {
  /// Callback triggered when the download task is finished
  var didFinishDownloadingTask: ((URLSessionDownloadTask, URL) -> Void)?
  /// Callback triggered when there's an update on the download progress
  var downloadProgressUpdated: ((URLSessionDownloadTask, Double) -> Void)?

  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    didFinishDownloadingTask?(downloadTask, location)
  }

  func urlSession(
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
