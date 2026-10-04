//
//  LibraryRootView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import DirectoryWatcher
import SwiftUI

struct LibraryRootView: View {
  let showSecondOnboarding: () -> Void
  let showImport: () -> Void

  @State private var path = [LibraryNode]()

  @State private var newFolderName: String = ""
  @State private var isFirstLoad = true
  /// The Library tab is on screen: an import's placement prompt can't be presented from a hidden tab
  @State private var isVisible = false

  @State private var importOperationState = ImportOperationState()
  @State private var loadingState = LoadingOverlayState()

  @StateObject private var documentFolderWatcher = DirectoryWatcher.watch(
    DataManager.getDocumentsFolderURL(),
    ignoreDirectories: false
  )!
  @StateObject private var sharedFolderWatcher = DirectoryWatcher.watch(
    DataManager.getSharedFilesFolderURL(),
    ignoreDirectories: false
  )!

  /// Environment
  @StateObject private var theme = ThemeViewModel()

  @EnvironmentObject private var playerManager: PlayerManager
  @EnvironmentObject private var importManager: ImportManager
  @EnvironmentObject private var externalImportEvents: ExternalImportEvents
  @EnvironmentObject private var singleFileDownloadService: SingleFileDownloadService
  @EnvironmentObject private var listSyncRefreshService: ListSyncRefreshService

  @Environment(\.listState) private var listState
  @Environment(\.playerState) private var playerState
  @Environment(\.libraryService) private var libraryService
  @Environment(\.playbackService) private var playbackService
  @Environment(\.syncService) private var syncService
  @Environment(\.hardcoverService) private var hardcoverService
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    NavigationStack(path: $path) {
      ItemListView {
        ItemListViewModel(
          libraryNode: .root,
          libraryService: libraryService,
          playbackService: playbackService,
          playerManager: playerManager,
          syncService: syncService,
          listSyncRefreshService: listSyncRefreshService,
          loadingState: loadingState,
          listState: listState,
          singleFileDownloadService: singleFileDownloadService
        )
      }
      .navigationDestination(for: LibraryNode.self) { node in
        ItemListView {
          ItemListViewModel(
            libraryNode: node,
            libraryService: libraryService,
            playbackService: playbackService,
            playerManager: playerManager,
            syncService: syncService,
            listSyncRefreshService: listSyncRefreshService,
            loadingState: loadingState,
            listState: listState,
            singleFileDownloadService: singleFileDownloadService
          )
        }
        .navigationBarTitleDisplayMode(.inline)
        .errorAlert(error: $loadingState.error)
      }
      .errorAlert(error: $loadingState.error)
      .loadingOverlay(loadingState.show, message: loadingState.message)
      .onAppear {
        guard isFirstLoad else { return }

        isFirstLoad = false

        Task {
          await handleLibraryLoaded()
        }
      }
      .onChange(of: scenePhase) {
        guard scenePhase == .active else { return }
        showImport()
      }
      .onReceive(syncService.downloadErrorPublisher) { (relativePath, error) in
        let errorMessage = "\(relativePath)\n\(error.localizedDescription)"
        loadingState.error = BookPlayerError.networkError(errorMessage)
      }
      .onReceive(importManager.observeFiles()) { files in
        guard !files.isEmpty, !singleFileDownloadService.isDownloading else { return }

        showImport()
      }
      .onReceive(documentFolderWatcher.newFilesPublisher) { files in
        files.forEach { importManager.process($0) }
      }
      .onReceive(sharedFolderWatcher.newFilesPublisher) { files in
        files.forEach { importManager.process($0) }
      }
      .onReceive(importManager.operationPublisher) { operation in
        importOperationState.isOperationActive = true
        importOperationState.processingTitle = String.localizedStringWithFormat(
          "import_processing_description".localized,
          operation.files.count
        )
        operation.completionBlock = {
          DispatchQueue.main.async {
            self.importOperationState.isOperationActive = false
            self.importOperationState.processingTitle = ""
            self.handleOperationCompletion(.local(files: operation.processedFiles), suggestedFolderName: operation.suggestedFolderName)
          }
        }

        importManager.start(operation)
      }
      .onReceive(externalImportEvents.confirmedBatches) { externalResources in
        Task {
          self.handleOperationCompletion(.external(files: externalResources), suggestedFolderName: nil)
        }
      }
    }
    .modifier(
      ImportPlacementPrompt(
        model: ImportPlacementModel(
          libraryService: libraryService,
          syncService: syncService,
          playerManager: playerManager
        ),
        importOperationState: importOperationState,
        loadingState: loadingState,
        isLibraryVisible: isVisible,
        isImportScreenShown: importManager.isImportScreenShown
      )
    )
    .onAppear { isVisible = true }
    .onDisappear { isVisible = false }
    .tint(theme.linkColor)
    .environmentObject(theme)
    .environment(\.loadingState, loadingState)
    .environment(\.importOperationState, importOperationState)
  }

  func handleLibraryLoaded() async {
    await loadLastBookIfNeeded()
    /// Open the player on launch when enabled and a book is loaded. Checked here, after the load above,
    /// so it covers both a plain cold launch (where `loadLastBookIfNeeded` just loaded the last book)
    /// and the case where the book was already loaded by another scene (e.g. CarPlay) — which makes the
    /// `currentItem == nil` guard inside `loadLastBookIfNeeded` return early.
    if UserDefaults.standard.bool(forKey: Constants.UserDefaults.openPlayerOnAppLaunch),
       playerManager.currentItem != nil {
      playerState.showPlayer = true
    }
    importManager.notifyPendingFiles()
    showSecondOnboarding()

    let pendingActions = AppServices.shared.pendingURLActions
    AppServices.shared.pendingURLActions.removeAll()
    for action in pendingActions {
      ActionParserService.handleAction(action)
    }
  }

  func loadLastBookIfNeeded() async {
    guard
      playerManager.currentItem == nil,
      let libraryItem = libraryService.getLibraryLastItem()
    else { return }

    do {
      try await AppServices.shared.coreServices?.playerLoaderService.loadPlayer(
        libraryItem.relativePath,
        autoplay: false,
        recordAsLastBook: false
      )
      if UserDefaults.standard.bool(forKey: Constants.UserActivityPlayback) {
        UserDefaults.standard.removeObject(forKey: Constants.UserActivityPlayback)
        playerManager.play()
      }

      if UserDefaults.standard.bool(forKey: Constants.UserDefaults.showPlayer) {
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.showPlayer)
        playerState.showPlayer = true
      }
    } catch BPPlayerError.fileMissing {
      // Silent preload: if the last-played file is missing on disk,
      // swallow the error. The user will see the proper alert if/when
      // they explicitly try to play this book. Surfacing it here would
      // race with other cold-launch presentations (e.g. the import sheet).
    } catch {
      loadingState.error = error
    }
  }

  func handleOperationCompletion(_ importSource: ImportSource, suggestedFolderName: String?) {
    let filesCount: Int
    switch importSource {
    case .local(let files):
      filesCount = files.count
    case .external(let externals):
      filesCount = externals.count
    }
    
    guard filesCount > 0 else {
      return
    }

    /// Where the import lands: the location browsed now, not after the network calls below
    let importNode = path.last ?? .root

    let isStream: Bool = {
      if case .external = importSource { return true }
      return false
    }()
    let streamTitle = String.localizedStringWithFormat("import_processing_description".localized, filesCount)
    if isStream {
      // A file import shows its copying; a stream import has none, so its insert and Hardcover's
      // match get the same spinner
      importOperationState.isOperationActive = true
      importOperationState.processingTitle = streamTitle
    }

    Task { @MainActor in
      defer {
        // Unless a file import or a download has taken the spinner over since
        if isStream, importOperationState.processingTitle == streamTitle {
          importOperationState.isOperationActive = false
          importOperationState.processingTitle = ""
        }
      }

      /// The browsed folder as it is now: a sync pull can rename it while it's open, or replace it
      /// (the folder at its path then has another uuid, which the sync move must name), or delete
      /// it, which lands the import at the root
      func currentFolder(uuid: String, path: String) -> SimpleLibraryItem? {
        let currentPath = libraryService.getItemRefs(forUuids: [uuid]).first?.relativePath ?? path
        return libraryService.getSimpleItem(with: currentPath).flatMap { $0.type == .folder ? $0 : nil }
      }
      let landing = importNode.folderRelativePath.flatMap { currentFolder(uuid: importNode.uuid, path: $0) }
      /// Where the import ends up: a stream is created there, a file import is moved there below
      var landed = isStream ? landing : nil

      let processedItems: [SimpleLibraryItem]
      switch importSource {
      case .local(let files):
        processedItems = await libraryService.insertItems(from: files)
      case .external(let externals):
        // Created in the browsed folder; file imports are copied to the root and moved there below
        processedItems = await libraryService.insertItems(
          fromResources: externals,
          inside: landing?.relativePath
        )
      }

      /// Nothing created (no item in the batch could become a book): nothing to place
      guard !processedItems.isEmpty else { return }

      var itemIdentifiers = processedItems.map({ $0.relativePath })
      let itemIdentifiersPairs = processedItems.map({ LibraryItemRef(relativePath: $0.relativePath, uuid: $0.uuid) })
      do {
        await syncService.scheduleUpload(items: processedItems)
        /// Move imported files to current selected folder so the user can see them. Found again
        /// here, with nothing awaited before the moves: the copy and insert above can take seconds
        if !isStream,
          let landing,
          let destination = currentFolder(uuid: landing.uuid, path: landing.relativePath) {
          let folderRelativePath = destination.relativePath
          try libraryService.moveItems(itemIdentifiersPairs, inside: folderRelativePath)
          syncService.scheduleMove(
            items: itemIdentifiersPairs,
            to: LibraryItemRef(relativePath: folderRelativePath, uuid: destination.uuid)
          )
          /// Update identifiers after moving for the follow up action alert
          itemIdentifiers = itemIdentifiers.map({ "\(folderRelativePath)/\($0)" })
          landed = destination
        }
      } catch {
        loadingState.error = error
        return
      }

      /// Reload all items
      listState.reloadAll(padding: itemIdentifiers.count)

      await hardcoverService.processAutoMatch(for: processedItems)

      let availableFolders =
        self.libraryService.getItems(
          notIn: itemIdentifiers,
          parentFolder: landed?.relativePath
        )?.filter({ $0.type == .folder }) ?? []

      let singleFolder: SimpleLibraryItem? =
        processedItems.count == 1 && processedItems.allSatisfy({ $0.type == .folder })
        ? processedItems.first : nil
      let hasOnlyBooks = processedItems.allSatisfy({ $0.type == .book })

      var firstTitle: String?
      if let suggestedFolderName {
        firstTitle = suggestedFolderName
      } else if let relativePath = itemIdentifiers.first {
        /// Xcode Cloud is throwing an error on #keyPath(BookPlayerKit.LibraryItem.title)
        firstTitle =
          libraryService.getItemProperty(
            "title",
            relativePath: relativePath
          ) as? String
      }

      importOperationState.pendingPlacement = ImportPlacement(
        itemUuids: processedItems.map(\.uuid),
        hasOnlyBooks: hasOnlyBooks,
        singleFolderUuid: singleFolder?.uuid,
        availableFolders: availableFolders,
        suggestedFolderName: firstTitle,
        node: landed.map { .folder(title: $0.title, relativePath: $0.relativePath, uuid: $0.uuid) } ?? .root
      )
    }
  }
}

extension LibraryRootView {
  @MainActor
  final class Model {
    init() {}
  }
}

#Preview {
  LibraryRootView {
  } showImport: {
  }
}
