//
//  AudiobookShelfAudiobookDetailsViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

protocol AudiobookShelfAudiobookDetailsViewModelProtocol: ObservableObject {
  var item: AudiobookShelfLibraryItem { get }
  var details: AudiobookShelfAudiobookDetailsData? { get }
  var connectionService: AudiobookShelfConnectionService { get }
  var error: Error? { get set }

  @MainActor
  func fetchData()

  @MainActor
  func cancelFetchData()

  @MainActor
  func beginDownloadAudiobook(_ item: AudiobookShelfLibraryItem) throws
}

class AudiobookShelfAudiobookDetailsViewModel: AudiobookShelfAudiobookDetailsViewModelProtocol {

  let item: AudiobookShelfLibraryItem
  let connectionService: AudiobookShelfConnectionService
  @Published var details: AudiobookShelfAudiobookDetailsData?
  @Published var error: Error?
  private var singleFileDownloadService: SingleFileDownloadService

  private var fetchTask: Task<(), any Error>?

  init(
    item: AudiobookShelfLibraryItem,
    connectionService: AudiobookShelfConnectionService,
    singleFileDownloadService: SingleFileDownloadService
  ) {
    self.item = item
    self.connectionService = connectionService
    self.singleFileDownloadService = singleFileDownloadService
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
    let url = try connectionService.createItemDownloadUrl(item)
    singleFileDownloadService.handleDownload(url)
  }
}
