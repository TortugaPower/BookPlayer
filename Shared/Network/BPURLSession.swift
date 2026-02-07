//
//  BPURLSession.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 15/8/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import Combine
import Foundation

/// URL session meant for upload tasks
class BPURLSession {
  static let shared = BPURLSession()

  public let backgroundSession: URLSession
  public let backgroundCellularSession: URLSession
  public let progressPublisher: PassthroughSubject<(String, Double), Never>
  public let completionPublisher: PassthroughSubject<(URLSessionTask, Error?), Never>
  private var cellularDataObserver: NSKeyValueObservation?

  private init() {
    let progressPublisher = PassthroughSubject<(String, Double), Never>()
    let completionPublisher = PassthroughSubject<(URLSessionTask, Error?), Never>()
    let bundleIdentifier: String = Bundle.main.configurationValue(for: .bundleIdentifier)

    let delegate = BPTaskUploadDelegate()
    delegate.uploadProgressUpdated = { [progressPublisher] task, uploadProgress in
      guard let relativePath = task.taskDescription else { return }

      progressPublisher.send((relativePath, uploadProgress))
    }
    delegate.didFinishTask = { [completionPublisher] task, error in
      completionPublisher.send((task, error))
    }

    self.progressPublisher = progressPublisher
    self.completionPublisher = completionPublisher

    let configuration = URLSessionConfiguration.background(
      withIdentifier: "\(bundleIdentifier).background"
    )
    configuration.allowsCellularAccess = false

    self.backgroundSession = URLSession(
      configuration: configuration,
      delegate: delegate,
      delegateQueue: OperationQueue()
    )

    let configurationForCellular = URLSessionConfiguration.background(
      withIdentifier: "\(bundleIdentifier).background.cellular"
    )
    configurationForCellular.allowsCellularAccess = true

    self.backgroundCellularSession = URLSession(
      configuration: configurationForCellular,
      delegate: delegate,
      delegateQueue: OperationQueue()
    )
  }
}
