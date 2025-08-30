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
  let showPlayer: () -> Void
  let showImport: () -> Void

  @State private var path = [LibraryNode]()
  @State private var reloadCenter = ListReloadCenter()

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
          reloadCenter: reloadCenter,
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
            reloadCenter: reloadCenter,
            singleFileDownloadService: singleFileDownloadService
          )
        }
        .navigationBarTitleDisplayMode(.inline)
      }
      .errorAlert(error: $loadingState.error)
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
      .onChange(of: playerState.showPlayer) {
        if playerState.showPlayer {
          showPlayer()
          playerState.showPlayer = false
        }
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
            self.handleOperationCompletion(operation.processedFiles, suggestedFolderName: operation.suggestedFolderName)
          }
        }

        importManager.start(operation)
      }
    }
    .tint(theme.linkColor)
    .environmentObject(theme)
    .environment(\.loadingState, loadingState)
    .environment(\.reloadCenter, reloadCenter)
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
        showPlayer()
      }
    } catch {
      loadingState.error = error
    }
  }

  func handleOperationCompletion(_ files: [URL], suggestedFolderName: String?) {
    guard !files.isEmpty else { return }

    Task { @MainActor in
      let processedItems = libraryService.insertItems(from: files)
      var itemIdentifiers = processedItems.map({ $0.relativePath })
      do {
        await syncService.scheduleUpload(items: processedItems)
        /// Move imported files to current selected folder so the user can see them
        if let folderRelativePath = path.last?.folderRelativePath {
          try libraryService.moveItems(itemIdentifiers, inside: folderRelativePath)
          syncService.scheduleMove(items: itemIdentifiers, to: folderRelativePath)
          /// Update identifiers after moving for the follow up action alert
          itemIdentifiers = itemIdentifiers.map({ "\(folderRelativePath)/\($0)" })
        }
      } catch {
        loadingState.error = error
        return
      }

      /// Reload all items
      reloadCenter.reloadAll(padding: itemIdentifiers.count)

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
        itemIdentifiers: itemIdentifiers,
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
  } showPlayer: {
  } showImport: {
  }
}
