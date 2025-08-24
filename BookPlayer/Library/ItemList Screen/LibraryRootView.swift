//
//  LibraryRootView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

typealias ImportVolumeParams = (hasOnlyBooks: Bool, singleFolder: SimpleLibraryItem?)

struct LibraryRootView: View {
  let showSecondOnboarding: () -> Void
  let showPlayer: () -> Void
  let showImport: () -> Void

  @State private var path = [LibraryNode]()
  @State private var reloadCenter = ListReloadCenter()

  @State private var showAddOptions = false
  @State private var showJellyfin = false

  @State private var showCreateFolderAlert = false
  @State private var newFolderName: String = ""
  @State private var isFirstLoad = true

  @State private var isImportOperationActive: Bool = false
  @State private var importProcessingTitle = ""

  @State private var loadingState = LoadingOverlayState()

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
  @Environment(\.jellyfinService) private var jellyfinService
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
          reloadCenter: reloadCenter
        )
      } addAction: {
        showAddOptions = true
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
            reloadCenter: reloadCenter
          )
        } addAction: {
          showAddOptions = true
        }
        .navigationBarTitleDisplayMode(.inline)
      }
      .toolbar {
        if isImportOperationActive {
          ToolbarItem(placement: .confirmationAction) {
            Menu {
              Text(importProcessingTitle)
            } label: {
              Image(systemName: "square.and.arrow.down")
                .symbolEffect(.pulse.wholeSymbol, options: .repeating)
                .foregroundStyle(theme.linkColor)
                .accessibilityLabel("import_preparing_title")
            }
          }
        }
      }
      .errorAlert(error: $loadingState.error)
      .confirmationDialog(
        "import_description",
        isPresented: $showAddOptions,
        titleVisibility: .visible
      ) {
        Button("import_button") {
          /// show document picker
        }
        Button("download_from_url_title") {
          /// show alert with textfield
        }
        Button("download_from_jellyfin_title") {
          showJellyfin = true
        }
        Button("create_playlist_button") {
          showCreateFolderAlert = true
        }
        Button("cancel_button", role: .cancel) {}
      }
      .sheet(isPresented: $showJellyfin) {
        JellyfinRootView(connectionService: jellyfinService)
      }
      .alert("create_playlist_title", isPresented: $showCreateFolderAlert) {
        TextField("new_playlist_button", text: $newFolderName)
        Button("create_button") {
          createFolder(with: newFolderName, type: .folder)
          newFolderName = ""
        }
        .disabled(newFolderName.isEmpty)
        Button("cancel_button", role: .cancel) {
          newFolderName = ""
        }
      }
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
      .onReceive(importManager.operationPublisher) { operation in
        isImportOperationActive = true
        importProcessingTitle = String.localizedStringWithFormat(
          "import_processing_description".localized,
          operation.files.count
        )
        operation.completionBlock = {
          DispatchQueue.main.async {
            self.isImportOperationActive = false
            self.importProcessingTitle = ""
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

  // TODO: Rework how operation completion is handled
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

      showOperationCompletedAlert(
        itemIdentifiers: itemIdentifiers,
        volumeParams: (hasOnlyBooks, singleFolder),
        availableFolders: availableFolders,
        suggestedFolderName: suggestedFolderName
      )
    }
  }

  // swiftlint:disable:next function_body_length
  func showOperationCompletedAlert(
    itemIdentifiers: [String],
    volumeParams: ImportVolumeParams,
    availableFolders: [SimpleLibraryItem],
    suggestedFolderName: String?
  ) {
    let hasParentFolder = path.last?.folderRelativePath != nil

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

    var actions = [BPActionItem]()

    if hasParentFolder {
      actions.append(BPActionItem(title: "current_playlist_title".localized))
    }

    actions.append(
      BPActionItem(
        title: "library_title".localized,
        handler: { [hasParentFolder, itemIdentifiers] in
          guard hasParentFolder else { return }

          self.importIntoLibrary(itemIdentifiers)
        }
      )
    )

    actions.append(
      BPActionItem(
        title: "new_playlist_button".localized,
        handler: { [firstTitle] in
          let placeholder = firstTitle ?? "new_playlist_button".localized

          self.showCreateFolderAlert(
            placeholder: placeholder,
            with: itemIdentifiers,
            type: .folder
          )
        }
      )
    )

    //    actions.append(BPActionItem(
    //      title: "existing_playlist_button".localized,
    //      isEnabled: !availableFolders.isEmpty,
    //      handler: { [itemIdentifiers, availableFolders] in
    //        self.onTransition?(.showItemSelectionScreen(
    //          availableItems: availableFolders,
    //          selectionHandler: { selectedFolder in
    //            self?.importIntoFolder(selectedFolder, items: itemIdentifiers, type: .folder)
    //          }
    //        ))
    //      }
    //    ))

    //    actions.append(BPActionItem(
    //      title: "bound_books_create_button".localized,
    //      isEnabled: volumeParams.hasOnlyBooks || volumeParams.singleFolder != nil,
    //      handler: { [firstTitle, weak self] in
    //        let placeholder = firstTitle ?? "bound_books_new_title_placeholder".localized
    //
    //        if volumeParams.hasOnlyBooks {
    //          self?.showCreateFolderAlert(placeholder: placeholder, with: itemIdentifiers, type: .bound)
    //        } else if let singleFolder = volumeParams.singleFolder {
    //          self?.updateFolders([singleFolder], type: .bound)
    //        }
    //      }
    //    ))

    /// Register that at least one import operation has completed
    BPSKANManager.updateConversionValue(.import)

    //    sendEvent(.showAlert(
    //      content: BPAlertContent(
    //        title: String.localizedStringWithFormat("import_alert_title".localized, itemIdentifiers.count),
    //        style: .alert,
    //        actionItems: actions
    //      )
    //    ))
  }

  func importIntoLibrary(_ items: [String]) {
    do {
      try libraryService.moveItems(items, inside: nil)
      syncService.scheduleMove(items: items, to: nil)
    } catch {
      loadingState.error = error
    }

    reloadCenter.reloadAll(padding: items.count)
  }

  func createFolder(with title: String, items: [String]? = nil, type: SimpleItemType) {
    Task { @MainActor in
      do {
        let folder = try libraryService.createFolder(
          with: title,
          inside: path.last?.folderRelativePath
        )
        await syncService.scheduleUpload(items: [folder])
        if let fetchedItems = items {
          try libraryService.moveItems(fetchedItems, inside: folder.relativePath)
          syncService.scheduleMove(items: fetchedItems, to: folder.relativePath)
        }
        try libraryService.updateFolder(at: folder.relativePath, type: type)
        libraryService.rebuildFolderDetails(folder.relativePath)

        // stop playback if folder items contain that current item
        if let items = items,
          let currentRelativePath = playerManager.currentItem?.relativePath,
          items.contains(currentRelativePath)
        {
          playerManager.stop()
        }

      } catch {
        loadingState.error = error
      }

      reloadCenter.reloadAll(padding: 1)
    }
  }

  func updateFolders(_ folders: [SimpleLibraryItem], type: SimpleItemType) {
    do {
      try folders.forEach { folder in
        try libraryService.updateFolder(at: folder.relativePath, type: type)

        if let currentItem = playerManager.currentItem,
          currentItem.relativePath.contains(folder.relativePath)
        {
          playerManager.stop()
        }
      }
    } catch {
      loadingState.error = error
    }

    reloadCenter.reloadAll()
  }

  func showCreateFolderAlert(
    placeholder: String? = nil,
    with items: [String]? = nil,
    type: SimpleItemType = .folder
  ) {
    let alertTitle: String
    let alertMessage: String
    let alertPlaceholderDefault: String

    switch type {
    case .folder:
      alertTitle = "create_playlist_title".localized
      alertMessage = ""
      alertPlaceholderDefault = "new_playlist_button".localized
    case .bound:
      alertTitle = "bound_books_create_alert_title".localized
      alertMessage = "bound_books_create_alert_description".localized
      alertPlaceholderDefault = "bound_books_new_title_placeholder".localized
    case .book:
      return
    }

    //    sendEvent(.showAlert(
    //      content: BPAlertContent(
    //        title: alertTitle,
    //        message: alertMessage,
    //        style: .alert,
    //        textInputPlaceholder: placeholder ?? alertPlaceholderDefault,
    //        actionItems: [
    //          BPActionItem(
    //            title: "create_button".localized,
    //            inputHandler: { [items, type] title in
    //              self.createFolder(with: title, items: items, type: type)
    //            }
    //          ),
    //          BPActionItem.cancelAction
    //        ]
    //      )
    //    ))
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
