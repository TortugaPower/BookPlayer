//
//  BPURLSession.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 15/8/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import Combine
import Foundation

/// The app's background transfer sessions, as iOS names them when it relaunches or wakes
/// the app for their events
public enum BackgroundTransferSessions {
  private static var bundleIdentifier: String {
    Bundle.main.configurationValue(for: .bundleIdentifier)
  }

  public static var uploadIdentifier: String { "\(bundleIdentifier).background" }
  public static var cellularUploadIdentifier: String { "\(bundleIdentifier).background.cellular" }
  public static var downloadIdentifier: String { "\(bundleIdentifier).background.download" }

  public static var uploadIdentifiers: Set<String> { [uploadIdentifier, cellularUploadIdentifier] }

  /// Recreates the upload sessions, which is what lets iOS deliver the events it held for them
  public static func activateUploadSessions() {
    _ = BPURLSession.shared
  }
}

/// URL session meant for upload tasks
class BPURLSession {
  static let shared = BPURLSession()

  public let backgroundSession: URLSession
  public let backgroundCellularSession: URLSession
  /// The emitting task and its bytes sent so far
  public let progressPublisher: PassthroughSubject<(URLSessionTask, Int64), Never>
  public let completionPublisher: PassthroughSubject<(URLSessionTask, Error?), Never>
  private var cellularDataObserver: NSKeyValueObservation?

  private init() {
    let progressPublisher = PassthroughSubject<(URLSessionTask, Int64), Never>()
    let completionPublisher = PassthroughSubject<(URLSessionTask, Error?), Never>()
    let delegate = BPTaskUploadDelegate()
    delegate.uploadProgressUpdated = { [progressPublisher] task, bytesSent in
      progressPublisher.send((task, bytesSent))
    }
    delegate.didFinishTask = { [completionPublisher] task, error in
      completionPublisher.send((task, error))
    }

    self.progressPublisher = progressPublisher
    self.completionPublisher = completionPublisher

    let configuration = URLSessionConfiguration.background(
      withIdentifier: BackgroundTransferSessions.uploadIdentifier
    )
    configuration.allowsCellularAccess = false

    self.backgroundSession = URLSession(
      configuration: configuration,
      delegate: delegate,
      delegateQueue: Self.serialDelegateQueue()
    )

    let configurationForCellular = URLSessionConfiguration.background(
      withIdentifier: BackgroundTransferSessions.cellularUploadIdentifier
    )
    configurationForCellular.allowsCellularAccess = true

    self.backgroundCellularSession = URLSession(
      configuration: configurationForCellular,
      delegate: delegate,
      delegateQueue: Self.serialDelegateQueue()
    )
  }

  /// Serial, so callbacks arrive in order: "finished events" follows the last completion,
  /// and a part's progress never lands after its completion
  static func serialDelegateQueue() -> OperationQueue {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    return queue
  }
}
