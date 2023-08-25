//
//  LibraryItemSyncJob.swift
//  BookPlayer
//
//  Created by gianni.carlo on 5/3/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Combine
import Foundation
import SwiftQueue

public enum JobType: String {
  case upload
  case update
  case move
  case renameFolder
  case delete
  case shallowDelete
  case setBookmark
  case deleteBookmark
  case uploadArtwork
  
  var identifier: String {
    return "BKPLY-\(self.rawValue)"
  }
}

class LibraryItemSyncJob: Job, BPLogger {
  static let type = "LibraryItemSyncJob"
  
  let client: NetworkClientProtocol
  let provider: NetworkProvider<LibraryAPI>
  let relativePath: String
  let jobType: JobType
  let parameters: [String: Any]
  
  private var progressSubscriber: AnyCancellable?
  private var completionSubscriber: AnyCancellable?
  
  /// Initializer
  /// - Parameters:
  ///   - client: Network client
  ///   - parameters: Library item info in dictionary form
  init(
    client: NetworkClientProtocol,
    relativePath: String,
    jobType: JobType,
    parameters: [String: Any]
  ) {
    self.client = client
    self.provider = NetworkProvider(client: client)
    self.relativePath = relativePath
    self.jobType = jobType
    self.parameters = parameters
  }
  
  // swiftlint:disable:next function_body_length
  func onRun(callback: SwiftQueue.JobResult) {
    Task { [weak self, callback] in
      guard let self = self else {
        callback.done(.fail(BookPlayerError.runtimeError("Deallocated self in LibraryItemUploadJob")))
        return
      }
      
      do {
        switch self.jobType {
        case .upload:
          guard
            let rawType = parameters["type"] as? Int16,
            let type = SimpleItemType(rawValue: rawType)
          else {
            throw BookPlayerError.runtimeError("Missing parameters for uploading")
          }
          
          try await self.handleUploadJob(type: type, callback: callback)
        case .update:
          let _: UploadItemResponse = try await self.provider.request(.update(params: self.parameters))
          callback.done(.success)
        case .move:
          guard
            let origin = parameters["origin"] as? String,
            let destination = parameters["destination"] as? String
          else {
            throw BookPlayerError.runtimeError("Missing parameters for moving")
          }
          let _: Empty = try await self.provider.request(.move(origin: origin, destination: destination))
          callback.done(.success)
        case .renameFolder:
          guard let name = parameters["name"] as? String else {
            throw BookPlayerError.runtimeError("Missing parameters for renaming")
          }
          
          let _: Empty = try await provider.request(.renameFolder(path: self.relativePath, name: name))
          callback.done(.success)
        case .delete:
          let _: Empty = try await provider.request(.delete(path: self.relativePath))
          callback.done(.success)
        case .shallowDelete:
          let _: Empty = try await provider.request(.shallowDelete(path: self.relativePath))
          callback.done(.success)
        case .setBookmark:
          try await handleSetBookmark()
          callback.done(.success)
        case .deleteBookmark:
          try await handleDeleteBookmark()
          callback.done(.success)
        case .uploadArtwork:
          try await handleUploadArtwork()
          callback.done(.success)
        }
      } catch {
        callback.done(.fail(error))
      }
    }
  }
  
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
  
  func handleUploadJob(
    type: SimpleItemType,
    callback: SwiftQueue.JobResult
  ) async throws {
    let response: UploadItemResponse = try await self.provider.request(.upload(params: self.parameters))
    
    guard let remoteURL = response.content.url else {
      /// The file is already present in the storage
      try await markUploadAsSynced(relativePath: self.relativePath)
      callback.done(.success)
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
      callback.done(.success)
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
      callback.done(.success)
      return
    }
    
    await uploadFile(
      fileURL: fileURL,
      remoteURL: remoteURL,
      relativePath: self.relativePath,
      callback: callback
    )
  }
  
  /// Upload file on a background thread, the callback can't be used,
  /// so it's up to the queue manager to remove the job once it's done
  func uploadFile(
    fileURL: URL,
    remoteURL: URL,
    relativePath: String,
    callback: SwiftQueue.JobResult
  ) async {
    let uploadTask = await self.client.uploadTask(
      fileURL,
      remoteURL: remoteURL,
      taskDescription: relativePath,
      session: BPURLSession.shared.backgroundSession
    )
    
    progressSubscriber?.cancel()
    progressSubscriber = BPURLSession.shared.progressPublisher.sink(receiveValue: { (path, progress) in
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
    completionSubscriber = BPURLSession.shared.completionPublisher.sink(receiveValue: { [weak self, callback] (task, error) in
      if let error {
        callback.done(.fail(error))
      } else {
        self?.handleUploadFinished(task, callback: callback)
      }
    })
    
    uploadTask.resume()
  }
  
  func handleUploadFinished(_ task: URLSessionTask, callback: SwiftQueue.JobResult) {
    Task { [task, callback] in
      do {
        if let relativePath = task.taskDescription {
          try await markUploadAsSynced(relativePath: relativePath)
        }
        NotificationCenter.default.post(name: .uploadCompleted, object: task)
        callback.done(.success)
      } catch {
        callback.done(.fail(error))
      }
    }
  }
  
  func markUploadAsSynced(relativePath: String) async throws {
    let _: UploadItemResponse = try await self.provider.request(.update(params: [
      "relativePath": relativePath,
      "synced": true
    ]))
  }
  
  func onRetry(error: Error) -> SwiftQueue.RetryConstraint {
    return .retry(delay: 5)
  }
  
  func onRemove(result: SwiftQueue.JobCompletion) {
    switch result {
    case .success:
      Self.logger.trace("Finished \(self.jobType.rawValue) for: \(self.relativePath)")
    case .fail(let error):
      Self.logger.error("Error on jobType \(self.jobType.rawValue) for \(self.relativePath): \(error.localizedDescription)")
    }
  }
}

struct LibraryItemUploadJobCreator: JobCreator {
  func create(type: String, params: [String: Any]?) -> SwiftQueue.Job {
    guard
      type == LibraryItemSyncJob.type,
      let relativePath = params?["relativePath"] as? String,
      let jobTypeRaw = params?["jobType"] as? String,
      let jobType = JobType(rawValue: jobTypeRaw)
    else { fatalError("Wrong job type") }
    
    return LibraryItemSyncJob(
      client: NetworkClient(),
      relativePath: relativePath,
      jobType: jobType,
      parameters: params ?? [:]
    )
  }
}
