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

struct JellyfinAudiobookDetailsData {
  let artist: String?
  let filePath: String?
  let fileSize: Int?
  let overview: String?
  let runtimeInSeconds: TimeInterval?

  var fileSizeString: String {
    if let fileSize {
      ByteCountFormatter.string(
        fromByteCount: Int64(fileSize),
        countStyle: ByteCountFormatter.CountStyle.file
      )
    } else {
      "file_size_unknown".localized
    }
  }

  var runtimeString: String {
    if let runtimeInSeconds {
      return TimeParser.formatTotalDuration(runtimeInSeconds)
    } else {
      return "runtime_unknown".localized
    }
  }
}

protocol JellyfinAudiobookDetailsViewModelProtocol: ObservableObject {
  var item: JellyfinLibraryItem { get }
  var details: JellyfinAudiobookDetailsData? { get }
  var connectionService: JellyfinConnectionService { get }
  var error: Error? { get set }

  @MainActor
  func fetchData()

  @MainActor
  func cancelFetchData()

  @MainActor
  func beginDownloadAudiobook(_ item: JellyfinLibraryItem) throws
}

class JellyfinAudiobookDetailsViewModel: JellyfinAudiobookDetailsViewModelProtocol {

  let item: JellyfinLibraryItem
  let connectionService: JellyfinConnectionService
  @Published var details: JellyfinAudiobookDetailsData?
  @Published var error: Error?
  private var singleFileDownloadService: SingleFileDownloadService

  private var fetchTask: Task<(), any Error>?

  init(
    item: JellyfinLibraryItem,
    connectionService: JellyfinConnectionService,
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
  func beginDownloadAudiobook(_ item: JellyfinLibraryItem) throws {
    let url = try connectionService.createItemDownloadUrl(item)
    singleFileDownloadService.handleDownload(url)
  }
}
