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
  @EnvironmentObject private var singleFileDownloadService: SingleFileDownloadService
  @EnvironmentObject private var listSyncRefreshService: ListSyncRefreshService

  @Environment(\.listState) private var listState
  @Environment(\.playerState) private var playerState
  @Environment(\.libraryService) private var libraryService
  @Environment(\.playbackService) private var playbackService
  @Environment(\.syncService) private var syncService
  @Environment(\.concurrenceService) private var concurrenceService
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
          playerState: playerState,
          syncService: syncService,
          concurrenceService: concurrenceService,
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
            playerState: playerState,
            syncService: syncService,
            concurrenceService: concurrenceService,
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
      .onReceive(importManager.externalOperationPublisher) { externalResources in
        Task {
          self.handleOperationCompletion(.external(files: externalResources), suggestedFolderName: nil)
        }
      }
    }
    .tint(theme.linkColor)
    .environmentObject(theme)
    .environment(\.loadingState, loadingState)
    .environment(\.importOperationState, importOperationState)
  }

  func handleLibraryLoaded() async {
    await loadLastBookIfNeeded()
    importManager.notifyPendingFiles()
    showSecondOnboarding()

    if let appDelegate = AppDelegate.shared {
      for action in appDelegate.pendingURLActions {
        ActionParserService.handleAction(action)
      }
    }
  }

  func loadLastBookIfNeeded() async {
    guard
      let libraryItem = libraryService.getLibraryLastItem()
    else { return }

    do {
      try await AppDelegate.shared?.coreServices?.playerLoaderService.loadPlayer(
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

    Task { @MainActor in
      let processedItems: [SimpleLibraryItem]
      switch importSource {
      case .local(let files):
        processedItems = await libraryService.insertItems(from: files)
      case .external(let externals):
        processedItems = await libraryService.insertItems(from: externals)
      }
      
      var itemIdentifiers = processedItems.map({ $0.relativePath })
      let itemIdentifiersPairs = processedItems.map({ PathUuidPair(relativePath: $0.relativePath, uuid: $0.uuid) })
      do {
        await syncService.scheduleUpload(items: processedItems)
        /// Move imported files to current selected folder so the user can see them
        if let lastItem = path.last,
           let folderRelativePath = lastItem.folderRelativePath {
          try libraryService.moveItems(itemIdentifiersPairs, inside: folderRelativePath)
          syncService.scheduleMove(items: itemIdentifiersPairs, to: PathUuidPair(relativePath: folderRelativePath, uuid: lastItem.uuid ))
          /// Update identifiers after moving for the follow up action alert
          itemIdentifiers = itemIdentifiers.map({ "\(folderRelativePath)/\($0)" })
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
          parentFolder: path.last?.folderRelativePath
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

      importOperationState.alertParameters = .init(
        itemIdentifiers: itemIdentifiersPairs,
        hasOnlyBooks: hasOnlyBooks,
        singleFolder: singleFolder,
        availableFolders: availableFolders,
        suggestedFolderName: firstTitle,
        lastNode: path.last ?? .root
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
