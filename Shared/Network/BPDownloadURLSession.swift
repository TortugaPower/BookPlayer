//
//  BPDownloadURLSession.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 13/10/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Combine
import Foundation

/// URL session meant for download tasks
public class BPDownloadURLSession {
  public let backgroundSession: URLSession

  /// Initializer
  /// - Parameters:
  ///   - downloadProgressUpdated: Callback triggered when there's an update on the download progress
  ///   - didFinishDownloadingTask: Callback triggered when the download task is finished
  public init(
    downloadProgressUpdated: @escaping ((URLSessionDownloadTask, Double) -> Void),
    didFinishDownloadingTask: @escaping ((URLSessionDownloadTask, URL) -> Void)
  ) {
    let bundleIdentifier: String = Bundle.main.configurationValue(for: .bundleIdentifier)

    let delegate = BPTaskDownloadDelegate()
    
    delegate.downloadProgressUpdated = downloadProgressUpdated
    delegate.didFinishDownloadingTask = didFinishDownloadingTask

    self.backgroundSession = URLSession(
      configuration: URLSessionConfiguration.background(
        withIdentifier: "\(bundleIdentifier).background.download"
      ),
      delegate: delegate,
      delegateQueue: OperationQueue()
    )
  }
}
