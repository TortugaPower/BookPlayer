//
//  AudiobookShelfAudiobookDetailsViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

class AudiobookShelfAudiobookDetailsViewModel: IntegrationDetailsViewModelProtocol {
  let item: AudiobookShelfLibraryItem
  let connectionService: AudiobookShelfConnectionService
  let accountService: AccountService
  let importManager: ImportManager
  @Published var details: AudiobookShelfAudiobookDetailsData?
  @Published var error: Error?
  private var singleFileDownloadService: SingleFileDownloadService

  private var fetchTask: Task<(), any Error>?

  init(
    item: AudiobookShelfLibraryItem,
    connectionService: AudiobookShelfConnectionService,
    singleFileDownloadService: SingleFileDownloadService,
    accountService: AccountService,
    importManager: ImportManager,
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
  func beginDownloadAudiobook(_ item: AudiobookShelfLibraryItem) throws {
    let request = try connectionService.createItemDownloadRequest(item)
    singleFileDownloadService.handleDownload(request)
  }
  
  @MainActor
  func handleImportAudiobook(_ item: AudiobookShelfLibraryItem) throws {
    if accountService.hasStreamingEnabled() {
      virtualImportAudiobook(item)
    } else {
      try beginDownloadAudiobook(item)
    }
  }
  
  @MainActor
  func virtualImportAudiobook(_ item: AudiobookShelfLibraryItem) {
    Task { @MainActor in
      do {
        // Same contract as the bulk paths: list navigation hands us a MINIFIED item,
        // so hydrate it for the real file extension — never guessed.
        let hydrated = try await connectionService.fetchItems(ids: [item.id])
        guard let fileExt = hydrated.first?.fileExtension ?? item.fileExtension else {
          self.error = BookPlayerError.runtimeError("import_no_audio_files_alert".localized)
          return
        }

        let externalItem = item.asVirtualImportResource(
          fileExtension: fileExt,
          connectionService: connectionService,
          artworkSize: CGSize(width: 300, height: 300)
        )
        importManager.externalFiles.append(externalItem)
        importManager.isShowingExternalImportView = true
      } catch {
        self.error = error
      }
    }
  }
}
