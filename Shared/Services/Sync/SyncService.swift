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

  func delete(_ items: [SimpleLibraryItem], mode: DeleteMode) async throws

  /// Cancel all scheduled jobs
  func cancelAllJobs()
}

public final class SyncService: SyncServiceProtocol, BPLogger {
  let libraryService: LibrarySyncProtocol
  var jobManager: JobSchedulerProtocol
  let client: NetworkClientProtocol
  public var isActive = false {
    didSet {
      if isActive == false {
        jobManager.cancelAllJobs()
      }
    }
  }

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
    NotificationCenter.default.publisher(for: .logout, object: nil)
      .sink(receiveValue: { [weak self] _ in
        self?.cancelAllJobs()
      })
      .store(in: &disposeBag)

    jobManager.libraryFinishedSync = {
      UserDefaults.standard.set(
        true,
        forKey: Constants.UserDefaults.completedLibrarySync.rawValue
      )
    }
  }

  public func syncListContents(
    at relativePath: String?
  ) async throws -> ([SyncableItem], SyncableItem?)? {
    guard
      isActive,
      UserDefaults.standard.bool(forKey: Constants.UserDefaults.completedLibrarySync.rawValue) == true
    else {
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
      try await self.storeListItems(
        itemsToStore,
        parentFolder: relativePath
      )
    }
    /// Update data or store
    itemsToUpdate.forEach({ libraryService.updateInfo(from: $0) })

    return (fetchedItems, lastItemPlayed)
  }

  public func syncLibraryContents() async throws -> ([SyncableItem], SyncableItem?) {
    guard isActive else {
      throw BookPlayerError.networkError("Sync is not enabled")
    }

    /// Block any list syncing calls until the library sync is finished
    UserDefaults.standard.set(
      false,
      forKey: Constants.UserDefaults.completedLibrarySync.rawValue
    )

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
      try await self.storeLibraryItems(itemsToStore)
    }

    if let itemsToUpload = libraryService.getItemsToSync(remoteIdentifiers: fetchedIdentifiers),
       !itemsToUpload.isEmpty {
      handleItemsToUpload(itemsToUpload)
    } else {
      UserDefaults.standard.set(
        true,
        forKey: Constants.UserDefaults.completedLibrarySync.rawValue
      )
    }

    return (itemsToStore, lastItemPlayed)
  }

  func storeLibraryItems(_ syncedItems: [SyncableItem]) async throws {
    for item in syncedItems {
      switch item.type {
      case .book:
        libraryService.addBook(from: item, parentFolder: nil)
      case .bound:
        libraryService.addFolder(from: item, type: .bound, parentFolder: nil)
        try await fetchBoundContents(for: item)
      case .folder:
        libraryService.addFolder(from: item, type: .folder, parentFolder: nil)
      }
    }
  }

  func fetchBoundContents(for item: SyncableItem) async throws {
    guard item.type == .bound else { return }

    let (fetchedItems, _) = try await fetchContents(at: item.relativePath)

    guard !fetchedItems.isEmpty else { return }

    /// All fetched items inside a bound folder are always books
    for fetchedItem in fetchedItems {
      libraryService.addBook(from: fetchedItem, parentFolder: item.relativePath)
    }
  }

  func storeListItems(
    _ syncedItems: [SyncableItem],
    parentFolder: String?
  ) async throws {
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

extension SyncService {
  func handleItemsToUpload(_ items: [SyncableItem]) {
    let folders = items.filter({ $0.type != .book })

    var itemsToUpload = items

    for folder in folders {
      if let contents = self.libraryService.fetchSyncableNestedContents(at: folder.relativePath),
         !contents.isEmpty {
        itemsToUpload.append(contentsOf: contents)
      }
    }

    itemsToUpload.forEach({ [weak self] in self?.jobManager.scheduleLibraryItemUploadJob(for: $0) })
  }
}

// MARK: - Delete functionality
extension SyncService {
  public func delete(_ items: [SimpleLibraryItem], mode: DeleteMode) async throws {
    guard isActive else { return }

    for item in items {
      jobManager.scheduleDeleteJob(with: item.relativePath, mode: mode)
    }
  }
}
