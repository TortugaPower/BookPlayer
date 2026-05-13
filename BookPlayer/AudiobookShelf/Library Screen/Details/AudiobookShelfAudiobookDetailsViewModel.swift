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
  let importManager: ImportManager?
  @Published var details: AudiobookShelfAudiobookDetailsData?
  @Published var error: Error?
  private var singleFileDownloadService: SingleFileDownloadService

  private var fetchTask: Task<(), any Error>?

  init(
    item: AudiobookShelfLibraryItem,
    connectionService: AudiobookShelfConnectionService,
    singleFileDownloadService: SingleFileDownloadService,
    accountService: AccountService,
    importManager: ImportManager?,
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
    if accountService.hasLiteEnabled() {
      virtualImportAudiobook(item)
    } else {
      try beginDownloadAudiobook(item)
    }
  }
  
  @MainActor
  func virtualImportAudiobook(_ item: AudiobookShelfLibraryItem) {
    let fileExt = item.fileExtension ?? "m4a"
    let libraryItem = SimpleLibraryItem(
      title: item.title,
      details: item.authorName ?? "voiceover_unknown_author".localized,
      speed: 1,
      currentTime: Double(item.currentTime ?? 0),
      duration: Double(item.duration ?? 0),
      percentCompleted: (item.progress ?? 0 > 0 && item.duration ?? 0 > 0)
        ? Double(item.progress!) / Double(item.duration!) : 0,
      isFinished: item.isFinished ?? false,
      relativePath: "",
      remoteURL: nil,
      artworkURL: item.coverPath != nil ? URL(string: item.coverPath!) : nil,
      orderRank: 0,
      parentFolder: nil,
      originalFileName: "\(item.title).\(fileExt)",
      lastPlayDate: nil,
      type: .book,
      uuid: UUID().uuidString
    )
    
    let externalItem = SimpleExternalResource(
      id: UUID().hashValue,
      providerName: ExternalResource.ProviderName.audiobookshelf.rawValue,
      providerId: item.id,
      syncStatus: ExternalResource.SyncStatus.stream.rawValue,
      lastSyncedAt: nil,
      libraryItem: libraryItem
    )
    
    importManager?.externalFiles.append(externalItem)
    importManager?.isShowingExternalImportView = true
  }
}
