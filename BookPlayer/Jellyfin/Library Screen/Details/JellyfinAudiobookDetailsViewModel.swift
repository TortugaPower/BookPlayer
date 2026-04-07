//
//  JellyfinAudiobookDetailsViewModel.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-26.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation
import JellyfinAPI

protocol JellyfinAudiobookDetailsViewModelProtocol: ObservableObject {
  var item: JellyfinLibraryItem { get }
  var details: JellyfinAudiobookDetailsData? { get }
  var connectionService: JellyfinConnectionService { get }
  var accountService: AccountService { get }
  var error: Error? { get set }

  @MainActor
  func fetchData()

  @MainActor
  func cancelFetchData()
  
  @MainActor
  func handleImportAudiobook(_ item: JellyfinLibraryItem) throws

  @MainActor
  func beginDownloadAudiobook(_ item: JellyfinLibraryItem) throws
  
  @MainActor
  func virtualImportAudiobook(_ item: JellyfinLibraryItem) throws
}

class JellyfinAudiobookDetailsViewModel: JellyfinAudiobookDetailsViewModelProtocol {
  
  let item: JellyfinLibraryItem
  let connectionService: JellyfinConnectionService
  let accountService: AccountService
  let importManager: ImportManager?
  @Published var details: JellyfinAudiobookDetailsData?
  @Published var error: Error?
  private var singleFileDownloadService: SingleFileDownloadService

  private var fetchTask: Task<(), any Error>?

  init(
    item: JellyfinLibraryItem,
    connectionService: JellyfinConnectionService,
    singleFileDownloadService: SingleFileDownloadService,
    accountService: AccountService,
    importManager: ImportManager?
  ) {
    self.item = item
    self.connectionService = connectionService
    self.singleFileDownloadService = singleFileDownloadService
    self.accountService = accountService
    self.importManager = importManager
  }

  @MainActor
  func fetchData() {
    guard fetchTask == nil else {
      return
    }

    fetchTask = Task {
      defer { fetchTask = nil }

      do {
        let details = try await connectionService.fetchItemDetails(for: item.id)

        await MainActor.run {
          self.details = details
        }
      } catch is CancellationError {
        // ignore
      } catch {
        Task { @MainActor in
          self.error = error
        }
      }
    }
  }

  @MainActor
  func cancelFetchData() {
    fetchTask?.cancel()
    fetchTask = nil
  }
  
  @MainActor
  func handleImportAudiobook(_ item: JellyfinLibraryItem) throws {
    if accountService.hasLiteEnabled() {
      virtualImportAudiobook(item)
    } else {
      try beginDownloadAudiobook(item)
    }
  }

  @MainActor
  func beginDownloadAudiobook(_ item: JellyfinLibraryItem) throws {
    let url = try connectionService.createItemDownloadUrl(item)
    singleFileDownloadService.handleDownload(url)
  }
  
  @MainActor
  func virtualImportAudiobook(_ item: JellyfinLibraryItem) {
    let libraryItem = SimpleLibraryItem(
      title: item.name,
      details: self.details?.artist ?? "voiceover_unknown_author".localized,
      speed: 1,
      currentTime: Double(item.currentSeconds ?? 0),
      duration: Double(item.durationSeconds ?? 0),
      percentCompleted: (item.durationSeconds ?? 0 > 0 && item.currentSeconds ?? 0 > 0)
        ? Double(item.currentSeconds!) / Double(item.durationSeconds!) : 0,
      isFinished: item.isFinished ?? false,
      relativePath: "",
      remoteURL: nil,
      artworkURL: try? connectionService.createItemImageURL(item, size: CGSize(width: 200, height: 200)),
      orderRank: 0,
      parentFolder: nil,
      originalFileName: item.name,
      lastPlayDate: item.lastPlayedDate,
      type: .book,
      uuid: UUID().uuidString
    )
    
    let externalItem = SimpleExternalResource(
      providerName: ExternalResource.ProviderName.jellyfin.rawValue,
      providerId: item.id,
      syncStatus: ExternalResource.SyncStatus.notSynced.rawValue,
      lastSyncedAt: nil,
      libraryItem: libraryItem
    )
    
    importManager?.externalFiles.append(externalItem)
    importManager?.isShowingExternalImportView = true
  }
}
