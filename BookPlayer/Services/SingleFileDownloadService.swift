//
//  DownloadService.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-29.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine

final class SingleFileDownloadService: ObservableObject {
  public enum ErrorKind: Error {
    case general
    case network
  }
  public enum Events {
    case starting(url: URL)
    case progress(task: URLSessionTask, progress: Double)  // (0..1)
    case bytesWritten(task: URLSessionTask, bytesWritten: Int64)
    case finished(task: URLSessionTask)
    case error(ErrorKind, task: URLSessionTask, underlyingError: Error?)
  }

  public var eventsPublisher = PassthroughSubject<Events, Never>()

  private let networkClient: NetworkClientProtocol
  private var progressDelegate = BPTaskDownloadDelegate()
  private var disposeBag = Set<AnyCancellable>()

  public var isDownloading: Bool { !downloadQueue.isEmpty || currentTask != nil }
  public private(set) var downloadQueue: [(url: URL, folderName: String?)] = []

  private var currentTask: (task: URLSessionTask, folderName: String?)?
  private lazy var downloadSession: URLSession = {
    URLSession(
      configuration: URLSessionConfiguration.background(withIdentifier: "SingleFileDownloadService"),
      delegate: progressDelegate,
      delegateQueue: nil
    )
  }()

  public init(networkClient: NetworkClientProtocol) {
    self.networkClient = networkClient

    bindObservers()
  }

  private func sendEvent(_ event: Events) {
    eventsPublisher.send(event)
  }

  public func handleDownload(_ url: URL) {
    downloadQueue.append((url: url, folderName: nil))
    processNextDownload()
  }

  public func handleDownload(_ urls: [URL]) {
    downloadQueue.append(contentsOf: urls.map { (url: $0, folderName: nil) })
    processNextDownload()
  }

  public func handleDownload(_ url: URL, folderName: String) {
    downloadQueue.append((url: url, folderName: folderName))
    processNextDownload()
  }

  public func handleDownload(_ urls: [URL], folderName: String) {
    downloadQueue.append(contentsOf: urls.map { (url: $0, folderName: folderName) })
    processNextDownload()
  }

  private func processNextDownload() {
    Task { @MainActor in
      guard currentTask == nil, !downloadQueue.isEmpty else { return }

      let downloadItem = downloadQueue.removeFirst()
      sendEvent(.starting(url: downloadItem.url))

      let task = await networkClient.download(
        url: downloadItem.url,
        taskDescription: "SingleFileDownload-\(downloadItem.url.absoluteString)",
        session: downloadSession
      )
      currentTask = (task: task, folderName: downloadItem.folderName)
    }
  }

  private func bindObservers() {
    progressDelegate.downloadProgressUpdated = { [weak self] task, progress in
      self?.sendEvent(.progress(task: task, progress: progress))
    }

    progressDelegate.downloadBytesWrittenUpdated = { [weak self] task, bytesWritten in
      self?.sendEvent(.bytesWritten(task: task, bytesWritten: bytesWritten))
    }

    progressDelegate.didFinishDownloadingTask = { [weak self] task, fileURL, error in
      guard let self, fileURL != nil || error != nil else { return }

      self.sendEvent(.finished(task: task))
      if let error {
        self.sendEvent(.error(.network, task: task, underlyingError: error))
      } else if let fileURL {
        self.handleSingleDownloadTaskFinished(task, fileURL: fileURL)
      }

      if task === self.currentTask?.task {
        Task { @MainActor in
          self.currentTask = nil
          self.processNextDownload()
        }
      }
    }
  }

  private func handleSingleDownloadTaskFinished(_ task: URLSessionTask, fileURL: URL) {
    let filename =
      task.response?.suggestedFilename
      ?? task.originalRequest?.url?.lastPathComponent
      ?? fileURL.lastPathComponent

    var destinationURL: URL
    if let folderName = currentTask?.folderName {
      let folderURL = DataManager.getDocumentsFolderURL().appendingPathComponent(folderName)
      destinationURL = folderURL.appendingPathComponent(filename)

      do {
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
      } catch {
        destinationURL = DataManager.getDocumentsFolderURL().appendingPathComponent(filename)
      }
    } else {
      destinationURL = DataManager.getDocumentsFolderURL().appendingPathComponent(filename)
    }

    do {
      try FileManager.default.moveItem(at: fileURL, to: destinationURL)
    } catch {
      sendEvent(.error(.general, task: task, underlyingError: error))
    }
  }
}
