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

public final class SyncService: SyncServiceProtocol {
  let libraryService: LibraryServiceProtocol
  let client: NetworkClientProtocol
  private let provider: NetworkProvider<LibraryAPI>
  let manager: SwiftQueueManager

  @Published var isActive: Bool = false

  private var disposeBag = Set<AnyCancellable>()

  public init(
    libraryService: LibraryServiceProtocol,
    client: NetworkClientProtocol = NetworkClient()
  ) {
    self.libraryService = libraryService
    self.client = client
    self.provider = NetworkProvider(client: client)
    self.manager = SwiftQueueManagerBuilder(creator: BookUploadJobCreator()).build()
  }

  public func accountUpdated(_ customerInfo: CustomerInfo) {
    self.isActive = !customerInfo.activeSubscriptions.isEmpty
  }

  public func syncLibrary() async throws {
    let fetchedItems = try await fetchContents(at: "")

    let fetchedIdentifiers = fetchedItems.map({ $0.relativePath })

    let identifiersToSync = try self.libraryService.getItemIdentifiers(notIn: fetchedIdentifiers, parentFolder: nil)

    identifiersToSync.forEach({ scheduleUploadJob(for: $0) })

    let newItems = fetchedItems.filter({ !identifiersToSync.contains($0.relativePath) })

    self.storeLibraryItems(from: newItems)
  }

  func scheduleUploadJob(for relativePath: String) {
    JobBuilder(type: LibraryItemUploadJob.type)
      .persist()
      .retry(limit: .limited(3))
      .internet(atLeast: .cellular)
      .with(params: ["relativePath": relativePath])
      .schedule(manager: manager)
  }

  func storeLibraryItems(from syncedItems: [SyncedItem]) {
    syncedItems.forEach { item in
      switch item.type {
      case .book:
        self.libraryService.addBook(from: item, parentFolder: nil)
      case .bound:
        self.libraryService.addFolder(from: item, type: .book, parentFolder: nil)
      case .folder:
        self.libraryService.addFolder(from: item, type: .folder, parentFolder: nil)
      }
    }
  }

  public func fetchContents(at relativePath: String) async throws -> [SyncedItem] {
    let response: ContentsResponse = try await self.provider.request(.contents(path: relativePath))

    return response.content
  }
}
