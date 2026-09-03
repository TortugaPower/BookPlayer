//
//  JellyfinAudiobookDetailsViewModel.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-26.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation
import JellyfinAPI

class JellyfinAudiobookDetailsViewModel: IntegrationDetailsViewModelProtocol {
  typealias Item = JellyfinLibraryItem
  typealias Details = JellyfinAudiobookDetailsData
  
  let item: JellyfinLibraryItem
  let connectionService: JellyfinConnectionService
  let accountService: AccountService
  let importManager: ImportManager
  let navigation: BPNavigation
  let navigationTitle: String
  @Published var details: JellyfinAudiobookDetailsData?
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
    navigation.path.append(JellyfinLibraryLevelData.subscribe)
  }
  private var singleFileDownloadService: SingleFileDownloadService

  private var fetchTask: Task<(), any Error>?

  init(
    item: JellyfinLibraryItem,
    connectionService: JellyfinConnectionService,
    singleFileDownloadService: SingleFileDownloadService,
    accountService: AccountService,
    importManager: ImportManager,
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
  func handleImportAudiobook(_ item: JellyfinLibraryItem) async throws {
    if accountService.hasStreamingEnabled() {
      await virtualImportAudiobook(item)
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
  func virtualImportAudiobook(_ item: JellyfinLibraryItem) async {
    // Reentrancy guard: a double-tap mid-hydration must not run two imports
    guard !isImporting else { return }
    isImporting = true
    defer { isImporting = false }

    do {
      let resources = try await VirtualImportPipeline.run(
        items: [item],
        id: \.id,
        hydrateExtensions: { ids in
          // Same contract as the bulk paths: the extension comes from the server's
          // media sources or the item is not importable — never guessed
          let hydrated = try await self.connectionService.fetchItems(ids: ids)
          var extensions: [String: String] = [:]
          extensions[item.id] = hydrated.first?.details?.fileExtension ?? self.details?.fileExtension
          return extensions
        },
        buildResource: { item, fileExtension in
          item.asVirtualImportResource(
            fileExtension: fileExtension,
            detailsOverride: self.details,
            connectionService: self.connectionService,
            artworkSize: CGSize(width: 200, height: 200)
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
