//
//  DownloadService.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-29.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Combine
import BookPlayerKit

class SingleFileDownloadService
{
  public enum ErrorKind: Error {
    case general
    case network
  }
  public enum Events {
    case starting(url: URL)
    case progress(task: URLSessionTask, progress: Double) // (0..1)
    case finished(task: URLSessionTask)
    case error(ErrorKind, task: URLSessionTask, underlyingError: Error?)
  }

  public var eventsPublisher = PassthroughSubject<Events, Never>()

  private let networkClient: NetworkClientProtocol
  private var progressDelegate = BPTaskDownloadDelegate()
  private var disposeBag = Set<AnyCancellable>()

  public init(networkClient: NetworkClientProtocol) {
    self.networkClient = networkClient

    bindObservers()
  }

  private func sendEvent(_ event: Events) {
    eventsPublisher.send(event)
  }

  public func handleDownload(_ url: URL) {
    sendEvent(.starting(url: url))

    _ = networkClient.download(url: url, delegate: progressDelegate)
  }

  private func bindObservers() {
    progressDelegate.downloadProgressUpdated = { [weak self] task, progress in
      self?.sendEvent(.progress(task: task, progress: progress))
    }

    progressDelegate.didFinishDownloadingTask = { [weak self] task, fileURL, error in
      guard let self else { return }

      self.sendEvent(.finished(task: task))
      if let error {
        self.sendEvent(.error(.network, task: task, underlyingError: error))
      } else if let fileURL {
        self.handleSingleDownloadTaskFinished(task, fileURL: fileURL)
      }
    }
  }

  private func handleSingleDownloadTaskFinished(_ task: URLSessionTask, fileURL: URL) {
    let filename = task.response?.suggestedFilename
    ?? task.originalRequest?.url?.lastPathComponent
    ?? fileURL.lastPathComponent

    do {
      try FileManager.default.moveItem(
        at: fileURL,
        to: DataManager.getDocumentsFolderURL().appendingPathComponent(filename)
      )
    } catch {
      sendEvent(.error(.general, task: task, underlyingError: error))
    }
  }
}
