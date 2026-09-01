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
  @Published private(set) var isImporting = false
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
  func handleImportAudiobook(_ item: AudiobookShelfLibraryItem) async throws {
    if accountService.hasStreamingEnabled() {
      await virtualImportAudiobook(item)
    } else {
      try beginDownloadAudiobook(item)
    }
  }
  
  @MainActor
  func virtualImportAudiobook(_ item: AudiobookShelfLibraryItem) async {
    // Reentrancy guard: a double-tap mid-hydration must not run two imports
    guard !isImporting else { return }
    isImporting = true
    defer { isImporting = false }

    do {
      let imported = try await VirtualImportPipeline.run(
        items: [item],
        id: \.id,
        hydrateExtensions: { ids in
          // Same contract as the bulk paths: list navigation hands us a MINIFIED
          // item, so hydrate it for the real file extension — never guessed
          let hydrated = try await self.connectionService.fetchItems(ids: ids)
          var extensions: [String: String] = [:]
          extensions[item.id] = hydrated.first?.fileExtension ?? item.fileExtension
          return extensions
        },
        buildResource: { item, fileExtension in
          item.asVirtualImportResource(
            fileExtension: fileExtension,
            connectionService: self.connectionService,
            artworkSize: CGSize(width: 300, height: 300)
          )
        },
        importManager: importManager
      )
      if imported == 0 {
        self.error = BookPlayerError.runtimeError("import_no_audio_files_alert".localized)
      }
    } catch {
      self.error = error
    }
  }
}
