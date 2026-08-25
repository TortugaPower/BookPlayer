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
  var results: ApiResponse?
  var error: Error?
  
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
    self.uuid = task.uuid
  }

  private var executionTask: Task<Void, Never>?

  // TODO: split into separate Operations
  override func main() {
    executionTask = Task {
      do {
        // Cooperative cancellation: cancel() cancels this Task, and the async
        // URLSession calls below throw CancellationError at their next suspension
        // point — an in-flight op must not finish a PUT or post confirmations under
        // the NEXT signed-in account's token (NetworkClient reads the keychain token
        // per request).
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
      /// The file is already present in the storage
      try await markUploadAsSynced(uuid: self.uuid)
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

    results = .uploadMetadata(UploadResponse(uuid: self.uuid, filePath: fileURL.absoluteString, remotePath: remoteURL.absoluteString, relativePath: self.relativePath))
    // Deliberately NOT handleUploadFinished() here: a backing file still has to be PUT by the
    // FileUploadOperation this result schedules — confirming synced:true now lies to the server
    // if that upload later fails permanently. The metadata-only branch above confirms
    // immediately; this branch confirms from the file upload's completion.
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
  func handleExternalResourceToDownload() async throws {
    let response: UploadItemContent = try await self.provider.request(
      .externalResourceToDownload(uuid: uuid, uploaded: false)
    )
    
    let hardLinkURL = FileManager.default.temporaryDirectory.appendingPathComponent(self.relativePath)
    let fileURL = FileManager.default.fileExists(atPath: hardLinkURL.path)
      ? hardLinkURL
      : DataManager.getProcessedFolderURL().appendingPathComponent(self.relativePath)
    
    guard FileManager.default.fileExists(atPath: fileURL.path),
    let remoteUrl = response.url else {
      // Consuming on nil url is the server CONTRACT, not an accident: external_set answers
      // url == null when the account tier has no S3 (lite) or the object already exists —
      // both permanent for this task. A missing local file likewise can't heal by retrying.
      return
    }

    // Streamed straight from disk — audiobooks run into the GBs and must never be
    // materialized as a single in-memory Data. A failed upload THROWS so the task is
    // retried and the server is never told the file exists when it doesn't.
    // Foreground session by design (for now): this pipe upload runs inside the retrying
    // sync operation while the app is in use, matching the Android app's current behavior;
    // surviving app termination is the planned background-transfer follow-up on both
    // platforms, which needs the BPURLSession delegate machinery, not just a session swap.
    try await client.upload(fileURL: fileURL, remoteURL: remoteUrl)

    // The bytes are on S3 now — failing the operation on a flaky confirmation would
    // retry the uploaded:false branch and re-upload the entire (potentially multi-GB)
    // file. Retry just the confirmation instead, mirroring the synced:true handling
    // in ConcurrenceService.handleFinishedOperation.
    var confirmationError: Error?
    for attempt in 1...3 {
      do {
        let _: Empty = try await self.provider.request(
          .externalResourceToDownload(uuid: uuid, uploaded: true)
        )
        return
      } catch {
        confirmationError = error
        Self.logger.error("uploaded:true confirmation attempt \(attempt) failed for \(self.uuid): \(error.localizedDescription)")
        // Space out the attempts (same 2s as the ConcurrenceService sibling): a single
        // transient blip would otherwise burn all three back-to-back in under a second
        // and re-upload the file anyway
        if attempt < 3 {
          try? await Task.sleep(for: .seconds(2))
        }
      }
    }
    // Exhausted: CONSUME rather than throw. A failed operation is retried from the
    // top, which re-runs the uploaded:false branch and re-PUTs the whole file — the
    // exact waste this loop exists to avoid. The bytes are safely on S3; the server
    // still thinks the object isn't uploaded, so the next external_set round-trip
    // heals cheaply (it answers url == null for an already-existing object, which the
    // nil-url branch above consumes). Same bytes-are-on-S3 semantics as the
    // FileUploadOperation confirmation in ConcurrenceService.handleFinishedOperation.
    if let confirmationError {
      Self.logger.error(
        "uploaded:true confirmation exhausted for \(self.uuid), consuming (bytes on S3): \(confirmationError.localizedDescription)"
      )
    }
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
