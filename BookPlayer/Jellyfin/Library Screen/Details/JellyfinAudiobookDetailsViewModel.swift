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
    if accountService.hasStreamingEnabled() {
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
    Task { @MainActor in
      do {
        // Same contract as the bulk paths: the file extension comes from the server's
        // media sources or the item is not importable — never guessed.
        let hydrated = try await connectionService.fetchItems(ids: [item.id])
        guard let fileExt = hydrated.first?.details?.fileExtension ?? self.details?.fileExtension else {
          self.error = BookPlayerError.runtimeError("import_no_audio_files_alert".localized)
          return
        }

        let externalItem = item.asVirtualImportResource(
          fileExtension: fileExt,
          detailsOverride: self.details,
          connectionService: connectionService,
          artworkSize: CGSize(width: 200, height: 200)
        )
        importManager?.externalFiles.append(externalItem)
        importManager?.isShowingExternalImportView = true
      } catch {
        self.error = error
      }
    }
  }
}
