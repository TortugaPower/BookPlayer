//
//  SyncService.swift
//  BookPlayer
//
//  Created by gianni.carlo on 18/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Combine
import Foundation
import RevenueCat

public protocol SyncServiceProtocol {
  /// Flag to check if it can sync or not
  var isActive: Bool { get set }

  /// Fetch the contents at the relativePath and override local contents with the remote repsonse
  func syncListContents(
    at relativePath: String?
  ) async throws -> ([SyncableItem], SyncableItem?)?

  /// Fetch the top level of the library, store incoming items and upload new local items
  /// Note: Should only be called when the user logs in
  func syncLibraryContents() async throws -> ([SyncableItem], SyncableItem?)

  func getRemoteFileURLs(
    of relativePath: String,
    type: SimpleItemType
  ) async throws -> [RemoteFileURL]

  func downloadRemoteFiles(
    for relativePath: String,
    type: SimpleItemType,
    delegate: URLSessionTaskDelegate
  ) async throws -> [URLSessionDownloadTask]

  /// Cancel all scheduled jobs
  func cancelAllJobs()
}

public final class SyncService: SyncServiceProtocol, BPLogger {
  let libraryService: LibrarySyncProtocol
  let jobManager: JobSchedulerProtocol
  let client: NetworkClientProtocol
  public var isActive = false
  private let provider: NetworkProvider<LibraryAPI>

  private var disposeBag = Set<AnyCancellable>()

  public init(
    libraryService: LibrarySyncProtocol,
    jobManager: JobSchedulerProtocol = SyncJobScheduler(),
    client: NetworkClientProtocol = NetworkClient()
  ) {
    self.libraryService = libraryService
    self.jobManager = jobManager
    self.client = client
    self.provider = NetworkProvider(client: client)

    bindObservers()
  }

  func bindObservers() {
    NotificationCenter.default.publisher(for: .itemMetadatUploaded, object: nil)
      .sink(receiveValue: { [weak self] notification in
        guard
          let relativePath = notification.userInfo?["relativePath"] as? String,
          let urlPath = notification.userInfo?["url"] as? String
        else {
          return
        }

        self?.handleMetadataUploaded(for: relativePath, remoteUrlPath: urlPath)
      })
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .logout, object: nil)
      .sink(receiveValue: { [weak self] _ in
        self?.cancelAllJobs()
      })
      .store(in: &disposeBag)
  }

  func handleMetadataUploaded(for relativePath: String, remoteUrlPath: String) {
    guard let item = self.libraryService.getItem(with: relativePath) else {
      Self.logger.warning(
        "Library item not found after uploading metadata for \(relativePath), user may have deleted it"
      )
      return
    }

    switch item {
    case is Book:
      jobManager.scheduleFileUploadJob(for: relativePath, remoteUrlPath: remoteUrlPath)
    case is Folder:
      guard
        let contents = self.libraryService.fetchSyncableContents(at: item.relativePath, limit: nil, offset: nil),
        !contents.isEmpty
      else {
        /// Create empty folder if there are no internal files
        jobManager.scheduleFileUploadJob(for: relativePath, remoteUrlPath: remoteUrlPath)
        return
      }

      contents.forEach({ [weak self] in self?.jobManager.scheduleMetadataUploadJob(for: $0) })
    default:
      break
    }
  }

  public func syncListContents(
    at relativePath: String?
  ) async throws -> ([SyncableItem], SyncableItem?)? {
    guard isActive else {
      throw BookPlayerError.networkError("Sync is not enabled")
    }

    if relativePath == nil {
      UserDefaults.standard.set(
        Date().timeIntervalSince1970,
        forKey: Constants.UserDefaults.lastSyncTimestamp.rawValue
      )
    }

    let (fetchedItems, lastItemPlayed) = try await fetchContents(at: relativePath)

    guard !fetchedItems.isEmpty else { return nil }

    let libraryIdentifiers = libraryService.getItemIdentifiers(in: relativePath) ?? []

    var fetchedIdentifiers = [String]()
    var itemsToStore = [SyncableItem]()
    var itemsToUpdate = [SyncableItem]()

    for fetchedItem in fetchedItems {
      fetchedIdentifiers.append(fetchedItem.relativePath)
      if !libraryIdentifiers.contains(fetchedItem.relativePath) {
        itemsToStore.append(fetchedItem)
      } else {
        itemsToUpdate.append(fetchedItem)
      }
    }

    /// Remove items from the library that are not in the remote items
    try libraryService.removeItems(notIn: fetchedIdentifiers, parentFolder: relativePath)

    /// Store new items
    if !itemsToStore.isEmpty {
     try await self.storeLibraryItems(from: itemsToStore, parentFolder: relativePath)
    }
    /// Update data or store
    itemsToUpdate.forEach({ libraryService.updateInfo(from: $0) })

    return (fetchedItems, lastItemPlayed)
  }

  public func syncLibraryContents() async throws -> ([SyncableItem], SyncableItem?) {
    guard isActive else {
      throw BookPlayerError.networkError("Sync is not enabled")
    }

    UserDefaults.standard.set(
      Date().timeIntervalSince1970,
      forKey: Constants.UserDefaults.lastSyncTimestamp.rawValue
    )

    let (fetchedItems, lastItemPlayed) = try await fetchContents(at: nil)

    let libraryIdentifiers = libraryService.getItemIdentifiers(in: nil) ?? []

    var fetchedIdentifiers = [String]()
    var itemsToStore = [SyncableItem]()

    for fetchedItem in fetchedItems {
      fetchedIdentifiers.append(fetchedItem.relativePath)
      if !libraryIdentifiers.contains(fetchedItem.relativePath) {
        itemsToStore.append(fetchedItem)
      }
    }

    if !itemsToStore.isEmpty {
     try await self.storeLibraryItems(from: itemsToStore, parentFolder: nil)
    }

    if let itemsToUpload = libraryService.getItemsToSync(remoteIdentifiers: fetchedIdentifiers, parentFolder: nil),
       !itemsToUpload.isEmpty {
      itemsToUpload.forEach({ [weak self] in self?.jobManager.scheduleMetadataUploadJob(for: $0) })
    }

    return (itemsToStore, lastItemPlayed)
  }

  func storeLibraryItems(from syncedItems: [SyncableItem], parentFolder: String?) async throws {
    for item in syncedItems {
      switch item.type {
      case .book:
        self.libraryService.addBook(from: item, parentFolder: parentFolder)
      case .bound:
        self.libraryService.addFolder(from: item, type: .bound, parentFolder: parentFolder)
        _ = try await syncListContents(at: item.relativePath)
      case .folder:
        self.libraryService.addFolder(from: item, type: .folder, parentFolder: parentFolder)
      }
    }
  }

  public func fetchContents(at relativePath: String?) async throws -> ([SyncableItem], SyncableItem?) {
    let path: String
    if let relativePath = relativePath {
      path = "\(relativePath)/"
    } else {
      path = ""
    }

    let response: ContentsResponse = try await self.provider.request(.contents(path: path))

    return (response.content, response.lastItemPlayed)
  }

  public func getRemoteFileURLs(
    of relativePath: String,
    type: SimpleItemType
  ) async throws -> [RemoteFileURL] {
    let response: RemoteFileURLResponseContainer

    if type == .bound {
      response = try await provider.request(.remoteContentsURL(path: relativePath))
    } else {
      response = try await self.provider.request(.remoteFileURL(path: relativePath))
    }

    guard !response.content.isEmpty else {
      throw BookPlayerError.emptyResponse
    }

    return response.content
  }

  public func downloadRemoteFiles(
    for relativePath: String,
    type: SimpleItemType,
    delegate: URLSessionTaskDelegate
  ) async throws -> [URLSessionDownloadTask] {
    let remoteURLs = try await getRemoteFileURLs(of: relativePath, type: type)

    var tasks = [URLSessionDownloadTask]()

    for remoteURL in remoteURLs {
      /// TODO: handle expiration date
      let task = self.provider.client.download(
        url: remoteURL.url,
        taskDescription: remoteURL.relativePath,
        delegate: delegate
      )

      tasks.append(task)
    }

    return tasks
  }

  public func cancelAllJobs() {
    jobManager.cancelAllJobs()
  }
}
