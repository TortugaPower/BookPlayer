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
import SwiftQueue

public protocol SyncServiceProtocol {
  func accountUpdated(_ customerInfo: CustomerInfo)
  func syncLibrary() async throws
}

public final class SyncService: SyncServiceProtocol, BPLogger {
  let libraryService: LibraryServiceProtocol
  let client: NetworkClientProtocol
  private let provider: NetworkProvider<LibraryAPI>
  let manager: SwiftQueueManager
  let fileUploadManager: SwiftQueueManager

  @Published var isActive: Bool = false

  private var disposeBag = Set<AnyCancellable>()

  public init(
    libraryService: LibraryServiceProtocol,
    client: NetworkClientProtocol = NetworkClient()
  ) {
    self.libraryService = libraryService
    self.client = client
    self.provider = NetworkProvider(client: client)
    self.manager = SwiftQueueManagerBuilder(creator: LibraryItemMetadataUploadJobCreator())
      .set(persister: UserDefaultsPersister(key: LibraryItemMetadataUploadJob.type))
      .build()
    self.fileUploadManager = SwiftQueueManagerBuilder(creator: LibraryItemFileUploadJobCreator())
      .set(persister: UserDefaultsPersister(key: LibraryItemFileUploadJob.type))
      .build()

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
      scheduleFileUploadJob(for: relativePath, remoteUrlPath: remoteUrlPath)
    case is Folder:
      let contents = self.libraryService.fetchContents(at: item.relativePath, limit: nil, offset: nil)

      contents?.forEach({ [weak self] in self?.scheduleMetadataUploadJob(for: $0) })
    default:
      break
    }
  }

  public func accountUpdated(_ customerInfo: CustomerInfo) {
    self.isActive = !customerInfo.activeSubscriptions.isEmpty
  }

  public func syncLibrary() async throws {
    let fetchedItems = try await fetchContents()

    let fetchedIdentifiers = fetchedItems.map({ $0.relativePath })

    let itemsToSync = try self.libraryService.getItems(notIn: fetchedIdentifiers, parentFolder: nil)

    itemsToSync.forEach({ [weak self] in self?.scheduleMetadataUploadJob(for: $0) })

    let identifiersToSync = itemsToSync.map({ $0.relativePath })

    let newItems = fetchedItems.filter({ !identifiersToSync.contains($0.relativePath) })

    self.storeLibraryItems(from: newItems, parentFolder: nil)
  }

  func scheduleFileUploadJob(for relativePath: String, remoteUrlPath: String) {
    JobBuilder(type: LibraryItemFileUploadJob.type)
      .singleInstance(forId: relativePath)
      .persist()
      .retry(limit: .limited(3))
      .internet(atLeast: .wifi)
      .with(params: [
        "relativePath": relativePath,
        "remoteUrlPath": remoteUrlPath
      ])
      .schedule(manager: fileUploadManager)
  }

  func scheduleMetadataUploadJob(for item: LibraryItem) {
    let relativePath = item.relativePath!
    var parameters: [String: Any] = [
      "relativePath": relativePath,
      "originalFileName": item.originalFileName!,
      "title": item.title!,
      "details": item.details!,
      "speed": item.speed,
      "currentTime": item.currentTime,
      "duration": item.duration,
      "percentCompleted": item.percentCompleted,
      "isFinished": item.isFinished,
      "orderRank": item.orderRank,
      "type": item.getItemType()
    ]

    if let lastPlayTimestamp = item.lastPlayDate?.timeIntervalSince1970 {
      parameters["lastPlayDateTimestamp"] = lastPlayTimestamp
    }

    JobBuilder(type: LibraryItemMetadataUploadJob.type)
      .singleInstance(forId: relativePath)
      .persist()
      .retry(limit: .limited(3))
      .internet(atLeast: .wifi)
      .with(params: parameters)
      .schedule(manager: manager)
  }

  func storeLibraryItems(from syncedItems: [SyncedItem], parentFolder: String?) {
    syncedItems.forEach { item in
      switch item.type {
      case .book:
        self.libraryService.addBook(from: item, parentFolder: parentFolder)
      case .bound:
        self.libraryService.addFolder(from: item, type: .bound, parentFolder: parentFolder)
      case .folder:
        self.libraryService.addFolder(from: item, type: .regular, parentFolder: parentFolder)
      }
    }
  }

  public func fetchContents(at relativePath: String = "") async throws -> [SyncedItem] {
    let response: ContentsResponse = try await self.provider.request(.contents(path: relativePath))

    return response.content
  }
}
