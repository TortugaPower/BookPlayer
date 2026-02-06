//
//  LibraryItemSyncOperation.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 14/1/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation
import Combine

/// Reference: https://www.avanderlee.com/swift/asynchronous-operations/
class LibraryItemSyncOperation: Operation, BPLogger {
  // MARK: - Async operation properties

  private var cellularDataObserver: NSKeyValueObservation?
  private let lockQueue = DispatchQueue(label: "com.bookplayer.asyncoperation.synctask", attributes: .concurrent)
  override var isAsynchronous: Bool { true }

  private var _isExecuting: Bool = false
  override private(set) var isExecuting: Bool {
    get {
      return lockQueue.sync { () -> Bool in
        return _isExecuting
      }
    }
    set {
      willChangeValue(forKey: "isExecuting")
      lockQueue.sync(flags: [.barrier]) {
        _isExecuting = newValue
      }
      didChangeValue(forKey: "isExecuting")
    }
  }

  private var _isFinished: Bool = false
  override private(set) var isFinished: Bool {
    get {
      return lockQueue.sync { () -> Bool in
        return _isFinished
      }
    }
    set {
      willChangeValue(forKey: "isFinished")
      lockQueue.sync(flags: [.barrier]) {
        _isFinished = newValue
      }
      didChangeValue(forKey: "isFinished")
    }
  }

  // MARK: - Library sync properties

  let client: NetworkClientProtocol
  let provider: NetworkProvider<LibraryAPI>
  let relativePath: String
  let jobType: SyncJobType
  let parameters: [String: Any]
  var error: Error?
  let progress = Progress(totalUnitCount: 100)
  
  private var progressSubscriber: AnyCancellable?
  private var completionSubscriber: AnyCancellable?

  /// Initializer
  /// - Parameters:
  ///   - client: Network client
  ///   - task: Sync task to be handled in the operation
  init(
    client: NetworkClientProtocol,
    task: SyncTask
  ) {
    self.client = client
    self.provider = NetworkProvider(client: client)
    self.relativePath = task.relativePath
    self.jobType = task.jobType
    self.parameters = task.parameters
  }

  override func start() {
    guard !isCancelled else {
      finish()
      return
    }

    isFinished = false
    isExecuting = true
    main()
  }

  // TODO: split into separate Operations
  override func main() {
    Task {
      do {
        switch jobType {
        case .upload:
          guard
            let rawType = parameters["type"] as? Int16,
            let type = SimpleItemType(rawValue: rawType)
          else {
            throw BookPlayerError.runtimeError("Missing parameters for uploading")
          }

          try await self.handleUploadJob(type: type)
        case .update:
          let _: UploadItemResponse = try await self.provider.request(.update(params: self.parameters))
          finish()
        case .move:
          guard
            let origin = parameters["origin"] as? String,
            let destination = parameters["destination"] as? String
          else {
            throw BookPlayerError.runtimeError("Missing parameters for moving")
          }
          let _: Empty = try await self.provider.request(.move(origin: origin, destination: destination))
          finish()
        case .renameFolder:
          guard let name = parameters["name"] as? String else {
            throw BookPlayerError.runtimeError("Missing parameters for renaming")
          }

          let _: Empty = try await provider.request(.renameFolder(path: self.relativePath, name: name))
          finish()
        case .delete:
          let _: Empty = try await provider.request(.delete(path: self.relativePath))
          finish()
        case .shallowDelete:
          let _: Empty = try await provider.request(.shallowDelete(path: self.relativePath))
          finish()
        case .setBookmark:
          try await handleSetBookmark()
          finish()
        case .deleteBookmark:
          try await handleDeleteBookmark()
          finish()
        case .uploadArtwork:
          try await handleUploadArtwork()
          finish()
        }
      } catch {
        self.error = error
        finish()
      }
    }
  }

  func finish() {
    isExecuting = false
    isFinished = true
  }
}

// MARK: - Upload task

extension LibraryItemSyncOperation {
  func handleUploadJob(type: SimpleItemType) async throws {
    let response: UploadItemResponse = try await provider.request(.upload(params: parameters))

    guard let remoteURL = response.content.url else {
      /// The file is already present in the storage
      try await markUploadAsSynced(relativePath: self.relativePath)
      finish()
      return
    }

    guard type == .book else {
      let _: Empty = try await self.client.request(
        url: remoteURL,
        method: .put,
        parameters: nil,
        useKeychain: false
      )
      try await markUploadAsSynced(relativePath: self.relativePath)
      finish()
      return
    }

    let hardLinkURL = FileManager.default.temporaryDirectory.appendingPathComponent(self.relativePath)

    /// Prefer the hard link URL and fallback to recorded item path
    /// Note: the recorded item path may not have the item if the user moved it
    let fileURL = FileManager.default.fileExists(atPath: hardLinkURL.path)
    ? hardLinkURL
    : DataManager.getProcessedFolderURL().appendingPathComponent(self.relativePath)

    guard
      FileManager.default.fileExists(atPath: fileURL.path)
    else {
      /// Uploaded metadata will not have a backing file, but we'll have a backup of item data
      finish()
      return
    }

    await uploadFile(
      fileURL: fileURL,
      remoteURL: remoteURL,
      relativePath: self.relativePath
    )
  }

  /// Upload file on a background thread
  func uploadFile(
    fileURL: URL,
    remoteURL: URL,
    relativePath: String
  ) async {
    let session: URLSession = UserDefaults.standard.bool(forKey: Constants.UserDefaults.allowCellularData)
    ? BPURLSession.shared.backgroundCellularSession
    : BPURLSession.shared.backgroundSession

    let uploadTask = await self.client.uploadTask(
      fileURL,
      remoteURL: remoteURL,
      taskDescription: relativePath,
      session: session
    )

    bindUploadObservers()

    cellularDataObserver?.invalidate()
    cellularDataObserver = UserDefaults.standard.observe(
      \.userSettingsAllowCellularData,
       options: [.new]
    ) { [weak self] _, change in
      guard let newValue = change.newValue else { return }

      let previousSession: URLSession = newValue
      ? BPURLSession.shared.backgroundSession
      : BPURLSession.shared.backgroundCellularSession

      self?.rescheduleUploadFile(
        fileURL: fileURL,
        remoteURL: remoteURL,
        relativePath: relativePath,
        previousSession: previousSession
      )
    }

    uploadTask.resume()
  }

  func bindUploadObservers() {
    progressSubscriber?.cancel()
    progressSubscriber = BPURLSession.shared.progressPublisher.sink(receiveValue: { (path, progress) in
      self.progress.completedUnitCount = Int64(progress * 100)
      NotificationCenter.default.post(
        name: .uploadProgressUpdated,
        object: nil,
        userInfo: [
          "progress": progress,
          "relativePath": path
        ]
      )
    })

    completionSubscriber?.cancel()
    completionSubscriber = BPURLSession.shared.completionPublisher.sink(receiveValue: { [weak self] (task, error) in
      self?.cellularDataObserver?.invalidate()
      if let nserror = error as? NSError,
         nserror.domain == NSURLErrorDomain,
         nserror.code == NSURLErrorCancelled {
        /// Do nothing, as the task is already being rescheduled
      } else if let error {
        self?.error = error
        self?.finish()
      } else {
        self?.handleUploadFinished(task)
      }
    })
  }

  func rescheduleUploadFile(
    fileURL: URL,
    remoteURL: URL,
    relativePath: String,
    previousSession: URLSession
  ) {
    Task {
      let task = await previousSession.allTasks.filter({ $0.taskDescription == relativePath }).first
      task?.cancel()

      await self.uploadFile(
        fileURL: fileURL,
        remoteURL: remoteURL,
        relativePath: relativePath
      )
    }
  }

  func handleUploadFinished(_ task: URLSessionTask) {
    Task { [task] in
      do {
        if let relativePath = task.taskDescription {
          try await markUploadAsSynced(relativePath: relativePath)
        }
        NotificationCenter.default.post(name: .uploadCompleted, object: task)
        finish()
      } catch {
        self.error = error
        finish()
      }
    }
  }

  func markUploadAsSynced(relativePath: String) async throws {
    let _: UploadItemResponse = try await self.provider.request(.update(params: [
      "relativePath": relativePath,
      "synced": true
    ]))
  }
}

// MARK: - Bookmarks

extension LibraryItemSyncOperation {
  func handleSetBookmark() async throws {
    guard
      let time = parameters["time"] as? Double
    else {
      throw BookPlayerError.runtimeError("Missing parameters for creating a bookmark")
    }

    let _: Empty = try await provider.request(
      .setBookmark(
        path: self.relativePath,
        note: parameters["note"] as? String,
        time: time,
        isActive: true
      )
    )
  }

  func handleDeleteBookmark() async throws {
    guard
      let time = parameters["time"] as? Double
    else {
      throw BookPlayerError.runtimeError("Missing parameters for deleting a bookmark")
    }

    let _: Empty = try await provider.request(
      .setBookmark(
        path: self.relativePath,
        note: nil,
        time: time,
        isActive: false
      )
    )
  }
}

// MARK: - Artwork

extension LibraryItemSyncOperation {
  func handleUploadArtwork() async throws {
    let cachedImageURL = ArtworkService.getCachedImageURL(for: relativePath)

    /// Only continue if the artwork is cached
    guard let data = FileManager.default.contents(atPath: cachedImageURL.path) else { return }

    let filename = "\(UUID().uuidString)-\(Int(Date().timeIntervalSince1970)).jpg"
    let response: ArtworkResponse = try await self.provider.request(
      .uploadArtwork(path: relativePath, filename: filename, uploaded: nil)
    )

    try await client.upload(data, remoteURL: response.thumbnailURL)

    let _: Empty = try await self.provider.request(
      .uploadArtwork(path: relativePath, filename: filename, uploaded: true)
    )
  }
}
