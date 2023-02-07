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
  /// Fetch the contents list for the specific folder or library
  @discardableResult
  func fetchListContents(
    at relativePath: String?,
    shouldSync: Bool
  ) async throws -> ([SyncableItem], SyncableItem?)
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

  public func fetchListContents(
    at relativePath: String?,
    shouldSync: Bool
  ) async throws -> ([SyncableItem], SyncableItem?) {
    guard isActive else {
      throw BookPlayerError.networkError("Sync is not enabled")
    }
    /// Register last sync timestamp
    if shouldSync {
      UserDefaults.standard.set(
        Date().timeIntervalSince1970,
        forKey: Constants.UserDefaults.lastSyncTimestamp.rawValue
      )
    }

    let (fetchedItems, lastItemPlayed) = try await fetchContents(at: relativePath)

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
      self.storeLibraryItems(from: itemsToStore, parentFolder: relativePath)
    }

    if shouldSync,
       let itemsToSync = libraryService.getItemsToSync(remoteIdentifiers: fetchedIdentifiers, parentFolder: nil),
       !itemsToSync.isEmpty {
      itemsToSync.forEach({ [weak self] in self?.jobManager.scheduleMetadataUploadJob(for: $0) })
    }

    return (itemsToStore, lastItemPlayed)
  }

  func storeLibraryItems(from syncedItems: [SyncableItem], parentFolder: String?) {
    let syncedItems = syncedItems.sorted(by: { $0.orderRank < $1.orderRank })

    syncedItems.forEach { item in
      switch item.type {
      case .book:
        self.libraryService.addBook(from: item, parentFolder: parentFolder)
      case .bound, .folder:
        self.libraryService.addFolder(from: item, type: item.type, parentFolder: parentFolder)
      }
    }
  }

  public func fetchContents(at relativePath: String?) async throws -> ([SyncableItem], SyncableItem?) {
    let relativePath = relativePath ?? ""
    let response: ContentsResponse = try await self.provider.request(.contents(path: relativePath))

    return (response.content, response.lastItemPlayed)
  }

  public func cancelAllJobs() {
    jobManager.cancelAllJobs()
  }
}
