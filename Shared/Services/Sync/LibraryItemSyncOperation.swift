//
//  LibraryItemSyncOperation.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 14/1/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation

class LibraryItemSyncOperation: AsyncOperation, BPLogger, @unchecked Sendable {
  // MARK: - Library sync properties

  let client: NetworkClientProtocol
  let provider: NetworkProvider<LibraryAPI>
  let relativePath: String
  let uuid: String
  let jobType: SyncJobType
  let parameters: [String: Any]
  /// Whether the account's tier stores files in S3 (PRO). A book's `synced` means "its file
  /// is in S3", so on any other tier the app never confirms one
  let canUploadFiles: Bool

  /// Written from the operation's detached Task (and `cancel()`), read from the
  /// queue-thread completionBlock — lock-guarded like the base class's `didSucceed`
  /// so the reads have a happens-before edge with the writes.
  private let propertyLock = NSLock()
  private var _results: ApiResponse?
  var results: ApiResponse? {
    get {
      propertyLock.lock(); defer { propertyLock.unlock() }
      return _results
    }
    set {
      propertyLock.lock(); defer { propertyLock.unlock() }
      _results = newValue
    }
  }
  private var _error: Error?
  var error: Error? {
    get {
      propertyLock.lock(); defer { propertyLock.unlock() }
      return _error
    }
    set {
      propertyLock.lock(); defer { propertyLock.unlock() }
      _error = newValue
    }
  }
  
  /// Initializer
  /// - Parameters:
  ///   - client: Network client
  ///   - task: Sync task to be handled in the operation
  ///   - canUploadFiles: Whether the account's tier stores files in S3
  init(
    client: NetworkClientProtocol,
    task: SyncTask,
    canUploadFiles: Bool
  ) {
    self.client = client
    self.provider = NetworkProvider(client: client)
    self.relativePath = task.relativePath
    self.jobType = task.jobType
    self.parameters = task.parameters
    self.uuid = task.uuid
    self.canUploadFiles = canUploadFiles
  }

  /// Written in main() on the queue thread, read/cancelled by cancel() from any thread
  /// (logout/lapse) — same lock discipline as error/results, or cancel() can read a
  /// stale nil and skip cancelling the in-flight Task.
  private var _executionTask: Task<Void, Never>?
  private var executionTask: Task<Void, Never>? {
    get {
      propertyLock.lock(); defer { propertyLock.unlock() }
      return _executionTask
    }
    set {
      propertyLock.lock(); defer { propertyLock.unlock() }
      _executionTask = newValue
    }
  }

  // TODO: split into separate Operations
  override func main() {
    executionTask = Task {
      do {
        // Two flags cover every cancel interleaving — an in-flight op must not finish
        // a PUT or post confirmations under the NEXT signed-in account's token
        // (NetworkClient reads the keychain token per request):
        // 1. cancel() ran BEFORE this Task existed (the start()→assignment window):
        //    executionTask was nil there, so only the OPERATION flag catches it.
        guard !isCancelled else {
          finish()
          return
        }
        // 2. cancel() ran after: the propertyLock guarantees it saw the Task and set
        //    the TASK flag — checked here and at every URLSession suspension point.
        try Task.checkCancellation()
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
          let _: Empty = try await self.provider.request(.move(origin: origin, destination: destination, uuid: uuid))
          finish()
        case .renameFolder:
          guard let name = parameters["name"] as? String else {
            throw BookPlayerError.runtimeError("Missing parameters for renaming")
          }

          let _: Empty = try await provider.request(.renameFolder(path: self.relativePath, name: name, uuid: uuid))
          finish()
        case .delete:
          let _: Empty = try await provider.request(.delete(path: self.relativePath, uuid: uuid))
          finish()
        case .shallowDelete:
          let _: Empty = try await provider.request(.shallowDelete(path: self.relativePath, uuid: uuid))
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
        case .matchUuid:
          try await handleMatchUuids()
          finish()
        case .externalResource:
          let _: Empty = try await self.provider.request(.externalResource(params: self.parameters))
          finish()
        case .externalResourceToDownload:
          try await handleExternalResourceToDownload()
          finish()
        case .deleteExternalResource:
          guard
            let providerName = parameters["providerName"] as? String,
            let providerId = parameters["providerId"] as? String
          else {
            throw BookPlayerError.runtimeError("Missing parameters for deleting an external resource")
          }
          let _: Empty = try await self.provider.request(
            .deleteExternalResource(uuid: uuid, providerName: providerName, providerId: providerId)
          )
          finish()
        case .externalUpdate, .uploadFile:
          /// Handled by their dedicated operations, never routed here
          throw BookPlayerError.runtimeError("Unsupported job type for sync operation: \(jobType.rawValue)")
        }
      } catch {
        self.error = error
        finish()
      }
    }
  }

  override func finish() {
    didSucceed = error == nil
    super.finish()
  }

  override func cancel() {
    super.cancel()
    // Mark failed BEFORE finishing so a logout-cancelled op can never be treated
    // as succeeded, then release the queue slot; finish() is idempotent, so the
    // cancelled Task's own finish() later is a no-op.
    if error == nil {
      error = BookPlayerError.cancelledTask
    }
    executionTask?.cancel()
    if isExecuting { finish() }
  }
}

// MARK: - Upload task

extension LibraryItemSyncOperation {
  func handleUploadJob(type: SimpleItemType) async throws {
    /// `provider` is client-side metadata (gates the follow-up file upload); keep it out of the request
    let uploadParams = parameters.filter { $0.key != "provider" }
    let response: UploadItemResponse = try await provider.request(.upload(params: uploadParams))
    guard let remoteURL = response.content.url else {
      /// The file is already present in the storage (or the tier doesn't store files): the
      /// book's hard link scheduled for the upload will never be read
      if type == .book {
        SyncJobScheduler.removeHardLink(at: SyncJobScheduler.hardLinkURL(for: self.relativePath))
      }
      /// Without S3 access no URL only means "this tier stores no file", so a book stays
      /// unconfirmed: it's what lets its file go up if the account becomes PRO
      if type != .book || canUploadFiles {
        try await markUploadAsSynced(uuid: self.uuid)
      }
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
      try await markUploadAsSynced(uuid: self.uuid)
      finish()
      return
    }

    let hardLinkURL = SyncJobScheduler.hardLinkURL(for: self.relativePath)

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

    // The URL only says the server needs the bytes: the upload lane sends them as a
    // multipart upload, and the server marks the row synced when it assembles the file
    results = .uploadMetadata(UploadResponse(uuid: self.uuid, filePath: fileURL.absoluteString, relativePath: self.relativePath))
    finish()
  }

  func markUploadAsSynced(uuid: String) async throws {
    let _: UploadItemResponse = try await self.provider.request(.update(params: [
      "uuid": uuid,
      "relativePath": self.relativePath,
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
        isActive: true,
        uuid: uuid
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
        isActive: false,
        uuid: uuid
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
      .uploadArtwork(path: relativePath, filename: filename, uploaded: nil, uuid: uuid)
    )

    try await client.upload(data, remoteURL: response.thumbnailURL)

    let _: Empty = try await self.provider.request(
      .uploadArtwork(path: relativePath, filename: filename, uploaded: true, uuid: uuid)
    )
  }
}

extension LibraryItemSyncOperation {
  /// A media-server book finished downloading on a PRO account: its file goes to S3 like
  /// any book's, through the upload lane. Run from the sync lane so it follows the task
  /// that created the item's row; `complete` marks its media-server resources downloaded.
  func handleExternalResourceToDownload() async throws {
    let hardLinkURL = SyncJobScheduler.hardLinkURL(for: self.relativePath)
    let fileURL = FileManager.default.fileExists(atPath: hardLinkURL.path)
      ? hardLinkURL
      : DataManager.getProcessedFolderURL().appendingPathComponent(self.relativePath)

    // No file (or no uuid to name the book by): nothing to upload, and retrying can't heal it
    guard !uuid.isEmpty, FileManager.default.fileExists(atPath: fileURL.path) else { return }

    results = .uploadMetadata(
      UploadResponse(uuid: uuid, filePath: fileURL.absoluteString, relativePath: relativePath)
    )
  }
}

extension LibraryItemSyncOperation {
  func handleMatchUuids() async throws {
    guard
      let uuidsDictionary = parameters["uuids"] as? [String: String],
      uuidsDictionary.count > 0
    else {
      return
    }
    let response: MatchUuidsResponse = try await self.provider.request(
      .matchUuids(uuidsDictionary: uuidsDictionary)
    )
    
    self.results = .matchUuid(response)
  }
}
