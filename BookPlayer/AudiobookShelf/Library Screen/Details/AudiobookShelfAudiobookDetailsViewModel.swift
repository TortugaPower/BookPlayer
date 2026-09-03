//
//  AudiobookShelfAudiobookDetailsViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

class AudiobookShelfAudiobookDetailsViewModel: IntegrationDetailsViewModelProtocol {
  let item: AudiobookShelfLibraryItem
  let connectionService: AudiobookShelfConnectionService
  let accountService: AccountService
  let importManager: ImportManager
  let navigation: BPNavigation
  @Published var details: AudiobookShelfAudiobookDetailsData?
  @Published var error: Error?
  @Published private(set) var isImporting = false
  @Published var pendingImportBatch: ExternalImportBatch?
  private var disposeBag = Set<AnyCancellable>()

  var showSubscribeButton: Bool { !accountService.hasSyncEnabled() }
  var allowStream: Bool { accountService.hasStreamingEnabled() }

  @MainActor
  func confirmExternalImport(_ resources: [SimpleExternalResource]) {
    // Details imports keep you in the browser (today's flow — import another book
    // without re-navigating): send on the import bus, no dismissal
    importManager.externalOperationPublisher.send(resources)
  }

  @MainActor
  func goToSubscribe() {
    navigation.path.append(AudiobookShelfLibraryLevelData.subscribe)
  }
  private var singleFileDownloadService: SingleFileDownloadService

  private var fetchTask: Task<(), any Error>?

  init(
    item: AudiobookShelfLibraryItem,
    connectionService: AudiobookShelfConnectionService,
    singleFileDownloadService: SingleFileDownloadService,
    accountService: AccountService,
    importManager: ImportManager,
    navigation: BPNavigation
  ) {
    self.item = item
    self.connectionService = connectionService
    self.singleFileDownloadService = singleFileDownloadService
    self.accountService = accountService
    self.importManager = importManager
    self.navigation = navigation

    // Entitlements can change while this screen is on the stack (the Stream CTA
    // pushes the subscribe flow) — re-render on account updates so the CTAs flip
    NotificationCenter.default.publisher(for: .accountUpdate)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in self?.objectWillChange.send() }
      .store(in: &disposeBag)
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
      let resources = try await VirtualImportPipeline.run(
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
        }
      )
      guard !resources.isEmpty else {
        self.error = BookPlayerError.runtimeError("import_no_audio_files_alert".localized)
        return
      }
      // Stage as a VALUE for this screen's own confirmation sheet
      pendingImportBatch = ExternalImportBatch(resources: resources)
    } catch {
      self.error = error
    }
  }
}
