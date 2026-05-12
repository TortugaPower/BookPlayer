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

class JellyfinAudiobookDetailsViewModel: IntegrationDetailsViewModelProtocol {
  typealias Item = JellyfinLibraryItem
  typealias Details = JellyfinAudiobookDetailsData
  
  let item: JellyfinLibraryItem
  let connectionService: JellyfinConnectionService
  let accountService: AccountService
  let importManager: ImportManager?
  let navigation: BPNavigation
  let navigationTitle: String
  @Published var details: JellyfinAudiobookDetailsData?
  @Published var error: Error?
  private var singleFileDownloadService: SingleFileDownloadService

  private var fetchTask: Task<(), any Error>?

  init(
    item: JellyfinLibraryItem,
    connectionService: JellyfinConnectionService,
    singleFileDownloadService: SingleFileDownloadService,
    accountService: AccountService,
    importManager: ImportManager?,
    navigation: BPNavigation,
    navigationTitle: String
  ) {
    self.item = item
    self.connectionService = connectionService
    self.singleFileDownloadService = singleFileDownloadService
    self.accountService = accountService
    self.importManager = importManager
    self.navigation = navigation
    self.navigationTitle = navigationTitle
    self.details = nil
  }

  @MainActor
  func fetchData() {
    guard fetchTask == nil else {
      return
    }

    fetchTask = Task {
      defer { fetchTask = nil }

      do {
        let detailsData = try await connectionService.fetchItemDetails(for: item.id)

        await MainActor.run {
          self.details = detailsData
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
    let request = try connectionService.createItemDownloadRequest(item)
    singleFileDownloadService.handleDownload(request)
  }
  
  @MainActor
  func virtualImportAudiobook(_ item: JellyfinLibraryItem) {
    let fileExt = self.details?.fileExtension != nil
      ? ".\(self.details!.fileExtension!)"
      : ""
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
      originalFileName: "\(item.name)\(fileExt)",
      lastPlayDate: item.lastPlayedDate,
      type: .book,
      uuid: UUID().uuidString
    )
    
    let externalItem = SimpleExternalResource(
      id: Int(Date.timeIntervalBetween1970AndReferenceDate),
      providerName: ExternalResource.ProviderName.jellyfin.rawValue,
      providerId: item.id,
      syncStatus: ExternalResource.SyncStatus.stream.rawValue,
      lastSyncedAt: nil,
      libraryItem: libraryItem
    )
    
    importManager?.externalFiles.append(externalItem)
    importManager?.isShowingExternalImportView = true
  }
}
