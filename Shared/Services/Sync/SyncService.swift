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
  func accountUpdated(_ customerInfo: CustomerInfo)
  func syncLibrary() async throws
  func cancelAllJobs()
}

public final class SyncService: SyncServiceProtocol, BPLogger {
  let libraryService: LibrarySyncProtocol
  let jobManager: JobSchedulerProtocol
  let client: NetworkClientProtocol
  private let provider: NetworkProvider<LibraryAPI>

  @Published var isActive: Bool = false

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
      let contents = self.libraryService.fetchSyncableContents(at: item.relativePath, limit: nil, offset: nil)

      contents?.forEach({ [weak self] in self?.jobManager.scheduleMetadataUploadJob(for: $0) })
    default:
      break
    }
  }

  public func accountUpdated(_ customerInfo: CustomerInfo) {
    self.isActive = !customerInfo.activeSubscriptions.isEmpty
  }

  public func syncLibrary() async throws {
    UserDefaults.standard.set(
      Date().timeIntervalSince1970,
      forKey: Constants.UserDefaults.lastSyncTimestamp.rawValue
    )

    let fetchedItems = try await fetchContents()

    let fetchedIdentifiers = fetchedItems.map({ $0.relativePath })

    let itemsToSync = self.libraryService.getItems(notIn: fetchedIdentifiers, parentFolder: nil) ?? []

    itemsToSync.forEach({ [weak self] in self?.jobManager.scheduleMetadataUploadJob(for: $0) })

    let identifiersToSync = itemsToSync.map({ $0.relativePath })

    let newItems = fetchedItems.filter({ !identifiersToSync.contains($0.relativePath) })

    self.storeLibraryItems(from: newItems, parentFolder: nil)
  }

  func storeLibraryItems(from syncedItems: [SyncableItem], parentFolder: String?) {
    syncedItems.forEach { item in
      switch item.type {
      case .book:
        self.libraryService.addBook(from: item, parentFolder: parentFolder)
      case .bound:
        self.libraryService.addFolder(from: item, type: .bound, parentFolder: parentFolder)
      case .folder:
        self.libraryService.addFolder(from: item, type: .folder, parentFolder: parentFolder)
      }
    }
  }

  public func fetchContents(at relativePath: String = "") async throws -> [SyncableItem] {
    let response: ContentsResponse = try await self.provider.request(.contents(path: relativePath))

    return response.content
  }

  public func cancelAllJobs() {
    jobManager.cancelAllJobs()
  }
}
