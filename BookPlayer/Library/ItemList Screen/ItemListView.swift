//
//  ItemListView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ItemListView: View {
  @StateObject var model: ItemListViewModel

  @State private var showItemOptions = false
  @State private var showMoveOptions = false

  @State private var itemDetailsSelection: SimpleLibraryItem?
  @State private var showCreateFolderAlert = false
  @State private var newFolderName: String = ""
  @State private var newFolderPlaceholder: String = ""
  @State private var newFolderType: SimpleItemType = .folder

  @State private var showCancelDownloadAlert = false
  @State private var showWarningOffloadAlert = false

  @State private var showDeleteAlert = false

  @State private var showAddOptions = false
  @State private var showDocumentPicker = false
  @State private var showJellyfin = false
  @State private var showDownloadURLAlert = false
  @State private var downloadURLInput = ""
  @State private var showFoldersSelection = false

  @State private var showImportCompletionAlert = false

  @State private var playingItemParentPath: String?

  @Environment(\.libraryService) private var libraryService
  @Environment(\.accountService) private var accountService
  @Environment(\.syncService) private var syncService
  @Environment(\.hardcoverService) private var hardcoverService
  @Environment(\.playerLoaderService) private var playerLoaderService
  @Environment(\.jellyfinService) private var jellyfinService
  @Environment(\.reloadCenter) private var reloadCenter
  @Environment(\.playerState) private var playerState
  @Environment(\.loadingState) private var loadingState
  @Environment(\.importOperationState) private var importOperationState
  @Environment(\.scenePhase) private var scenePhase
  @EnvironmentObject private var importManager: ImportManager
  @EnvironmentObject private var theme: ThemeViewModel

  init(initModel: @escaping () -> ItemListViewModel) {
    self._model = .init(wrappedValue: initModel())
  }

  var body: some View {
    Group {
      if model.isListEmpty {
        EmptyListView(node: model.libraryNode) {
          showAddOptions = true
        }
      } else {
        List(selection: $model.selectedSetItems) {
          ForEach(model.filteredResults, id: \.id) { item in
            rowView(item)
              .allowsHitTesting(!model.editMode.isEditing)
          }
          .onMove { source, destination in
            model.reorderItems(source: source, destination: destination)
          }

          if model.canLoadMore {
            loadMoreView()
          }
        }
        .searchable(
          text: $model.query,
          prompt: "search_title".localized + " \(model.libraryNode.title)"
        )
        .searchScopes($model.scope) {
          ForEach(ItemListSearchScope.allCases) { scope in
            Text(scope.title).tag(scope)
          }
        }
        .environment(\.editMode, $model.editMode)
        .environment(\.playingItemParentPath, playingItemParentPath)
        .environment(\.libraryNode, model.libraryNode)
      }
    }
    .confirmationDialog(
      itemOptionsTitle,
      isPresented: $showItemOptions,
      titleVisibility: .visible
    ) {
      itemOptionsDialog()
    }
    .confirmationDialog(
      "import_description",
      isPresented: $showAddOptions,
      titleVisibility: .visible
    ) {
      addFilesOptions()
      Button("cancel_button", role: .cancel) {}
    }
    .alert(
      importOptionsTitle,
      isPresented: $showImportCompletionAlert,
      presenting: importOperationState.alertParameters
    ) { alertParameters in
      importOptions(for: alertParameters)
    }
    .alert("choose_destination_title", isPresented: $showMoveOptions) {
      moveOptions()
    }
    .alert(
      createFolderTitle,
      isPresented: $showCreateFolderAlert
    ) {
      createFolderOptions()
    } message: {
      if newFolderType == .bound {
        Text("bound_books_create_alert_description")
      }
    }
    .alert(
      model.deleteActionDetails()?.title ?? "",
      isPresented: $showDeleteAlert
    ) {
      deleteOptions()
    } message: {
      if let message = model.deleteActionDetails()?.message {
        Text(message)
      }
    }
    .alert("cancel_download_title", isPresented: $showCancelDownloadAlert) {
      Button("ok_button") {
        let item = model.selectedItems.first!
        model.cancelDownload(of: item)
      }
      Button("cancel_button", role: .cancel) {}
    }
    .alert("warning_title", isPresented: $showWarningOffloadAlert) {
      Button("ok_button") {
        let item = model.selectedItems.first!
        model.handleOffloading(of: item)
      }
      Button("cancel_button", role: .cancel) {}
    } message: {
      Text(String(format: "sync_tasks_item_upload_queued".localized, model.selectedItems.first?.relativePath ?? ""))
    }
    .alert("download_from_url_title", isPresented: $showDownloadURLAlert) {
      TextField(
        "https://",
        text: $downloadURLInput
      )
      Button("download_title") {
        model.downloadFromURL(downloadURLInput)
        downloadURLInput = ""
      }
      .disabled(downloadURLInput.isEmpty)
      Button("cancel_button", role: .cancel) {
        downloadURLInput = ""
      }
    }
    .sheet(item: $itemDetailsSelection) { item in
      NavigationStack {
        ItemDetailsView {
          ItemDetailsViewModel(
            item: item,
            libraryService: libraryService,
            syncService: syncService,
            hardcoverService: hardcoverService,
            reloadCenter: reloadCenter
          )
        }
      }
    }
    .onReceive(
      model.singleFileDownloadService.eventsPublisher
        .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
    ) { event in
      switch event {
      case .starting:
        let totalFiles = model.singleFileDownloadService.downloadQueue.count + 1
        let title = String.localizedStringWithFormat("downloading_file_title".localized, totalFiles)
        let subtitle = "\("progress_title".localized) 0%"

        importOperationState.isOperationActive = true
        importOperationState.processingTitle = "\(title)\n\(subtitle)"
      case .progress(_, let progress):
        let percentage = String(format: "%.2f", progress * 100)
        let totalFiles = model.singleFileDownloadService.downloadQueue.count + 1
        let title = String.localizedStringWithFormat("downloading_file_title".localized, totalFiles)
        let subtitle = "\("progress_title".localized) \(percentage)%"

        importOperationState.isOperationActive = true
        importOperationState.processingTitle = "\(title)\n\(subtitle)"
      case .finished:
        importOperationState.isOperationActive = false
        importOperationState.processingTitle = ""
      case .error(let errorKind, let task, let underlyingError):
        model.handleSingleFileDownloadError(
          errorKind,
          task: task,
          underlyingError: underlyingError
        )
      }
    }
    .task(id: playerState.loadedBookRelativePath) {
      playingItemParentPath = model.getPathForParentOfPlayingItem(playerState.loadedBookRelativePath)
    }
    .onChange(of: scenePhase) {
      guard scenePhase == .active else { return }

      Task {
        await model.syncList()
      }
    }
    .onChange(of: reloadCenter.token(for: .all), initial: false) {
      let padding = reloadCenter.padding(for: .all)
      model.reloadItems(with: padding)
    }
    .onChange(of: reloadCenter.token(for: model.reloadScope), initial: false) {
      let padding = reloadCenter.padding(for: model.reloadScope)
      model.reloadItems(with: padding)
    }
    .onChange(of: importOperationState.alertParameters) {
      guard
        let alertParameters = importOperationState.alertParameters,
        alertParameters.lastNode == model.libraryNode
      else { return }

      /// Register that at least one import operation has completed
      BPSKANManager.updateConversionValue(.import)
      showImportCompletionAlert = true
    }
    .onChange(of: showImportCompletionAlert) {
      /// Clean up after import
      if showImportCompletionAlert == false {
        importOperationState.alertParameters = nil
      }
    }
    .sheet(isPresented: $showJellyfin) {
      JellyfinRootView(connectionService: jellyfinService)
    }
    .sheet(isPresented: $showFoldersSelection) {
      ItemListSelectionView(items: model.getAvailableFolders()) { folder in
        model.handleMoveIntoFolder(folder)
      }
    }
    .fileImporter(
      isPresented: $showDocumentPicker,
      allowedContentTypes: [
        .audio,
        .movie,
        .zip,
        .folder,
      ],
      allowsMultipleSelection: true
    ) { result in
      switch result {
      case .success(let files):
        model.handleFilePickerSelection(files)
      case .failure(let error):
        loadingState.error = error
      }
    }
    .toolbar {
      mainToolbar()
    }
    .miniPlayerSafeAreaInset()
    .listStyle(.plain)
    .applyListStyle(with: theme, background: theme.systemBackgroundColor)
    .navigationTitle(model.navigationTitle)
  }

  @ViewBuilder
  private func rowView(_ item: SimpleLibraryItem) -> some View {
    Group {
      if item.type == .folder {
        FolderView(item: item)
      } else {
        BookView(item: item)
          .onTapGesture {
            switch syncService.getDownloadState(for: item) {
            case .downloading:
              model.selectedSetItems = [item.id]
              showCancelDownloadAlert = true
            case .downloaded, .notDownloaded:
              Task {
                do {
                  try await playerLoaderService.loadPlayer(item.relativePath, autoplay: true)
                  playerState.showPlayerBinding.wrappedValue = true
                } catch {
                  loadingState.error = error
                }
              }
            }
          }
      }
    }
    .onAppear {
      Task {
        await model.prefetchIfNeeded(for: item)
      }
    }
    .swipeActions(edge: .trailing) {
      Button {
        model.selectedSetItems = [item.id]
        showItemOptions = true
      } label: {
        Text("options_button")
      }
    }
    .listRowBackground(theme.systemBackgroundColor)
  }

  @ViewBuilder
  private func loadMoreView() -> some View {
    HStack {
      Spacer()
      ProgressView()
      Spacer()
    }
    .task { await model.loadNextPage() }
  }

  @ViewBuilder
  private func addFilesOptions() -> some View {
    Button("import_button", systemImage: "folder") {
      showDocumentPicker = true
    }
    Button("download_from_url_title", systemImage: "link") {
      showDownloadURLAlert = true
    }
    Button("download_from_jellyfin_title", image: .jellyfinIcon) {
      showJellyfin = true
    }
    Button("create_playlist_button", systemImage: "folder.badge.plus") {
      newFolderType = .folder
      newFolderName = ""
      newFolderPlaceholder = ""
      showCreateFolderAlert = true
    }
  }

  // MARK: - Toolbar
  @ToolbarContentBuilder
  private func mainToolbar() -> some ToolbarContent {
    ToolbarItemGroup(placement: .confirmationAction) {
      if !model.editMode.isEditing {
        regularToolbarTrailing()
      } else {
        editingToolbarTrailing()
      }
    }

    if model.editMode.isEditing {
      ToolbarItem(placement: .cancellationAction) {
        Button(
          model.selectedSetItems.count == model.items.count
          ? "deselect_all_title"
          : "select_all_title"
        ) {
          if model.selectedSetItems.count == model.items.count {
            model.selectedSetItems.removeAll()
          } else {
            model.selectedSetItems = Set(model.items.map { $0.id })
          }
        }
      }
      ToolbarItemGroup(placement: .bottomBar) {
        editingBottomBar()
      }
    }
  }

  @ViewBuilder
  private func regularToolbarTrailing() -> some View {
    if importOperationState.isOperationActive {
      Menu {
        Text(importOperationState.processingTitle)
      } label: {
        Image(systemName: "square.and.arrow.down")
          .symbolEffect(.pulse.wholeSymbol, options: .repeating)
          .foregroundStyle(theme.linkColor)
          .accessibilityLabel("import_preparing_title")
      }
    }

    Menu {
      Section {
        Button {
          withAnimation {
            model.selectedSetItems.removeAll()
            model.editMode = .active
          }
        } label: {
          Label("select_title".localized, systemImage: "checkmark.circle")
        }
      }

      Section {
        addFilesOptions()
      } header: {
        Text("playlist_add_title")
      }
    } label: {
      Label("more_title".localized, systemImage: "ellipsis.circle")
    }
  }

  @ViewBuilder
  private func editingToolbarTrailing() -> some View {
    Button {
      withAnimation {
        model.editMode = .inactive
        model.selectedSetItems.removeAll()
      }
    } label: {
      Text("done_title".localized).bold()
    }
  }

  @ViewBuilder
  private func editingBottomBar() -> some View {
    Button {
      print("")
    } label: {
      Image(systemName: model.selectedItems.isEmpty ? "checklist.checked" : "checklist.unchecked")
    }

    Spacer()
  }
}

// MARK: - Options dialog
extension ItemListView {
  private var itemOptionsTitle: String {
    let isSingle: Bool = model.selectedItems.count == 1
    let title: String = isSingle ? (model.selectedItems.first?.title ?? "") : "options_button".localized
    return title
  }

  @ViewBuilder
  private func itemOptionsDialog() -> some View {
    let item = model.selectedItems.first
    let isSingle = model.selectedItems.count == 1

    let areAllFinished: Bool = model.selectedItems.allSatisfy { $0.isFinished }
    let markTitle: String = areAllFinished
    ? "mark_unfinished_title".localized
    : "mark_finished_title".localized

    let allAreBound: Bool = model.selectedItems.allSatisfy { $0.type == .bound }
    let multipleBooks: Bool = model.selectedItems.count > 1 && model.selectedItems.allSatisfy { $0.type == .book }
    let singleFolder: Bool = isSingle && (item?.type == .folder)
    let canCreateBound: Bool = multipleBooks || singleFolder

    Button("details_title") {
      itemDetailsSelection = item
    }
    .disabled(!isSingle)
    Button("move_title") {
      showMoveOptions = true
    }

    if isSingle,
       let item
    {
      ShareLink(
        item: item,
        preview: SharePreview(
          item.relativePath,
          image: Image(systemName: item.type == .book ? "waveform" : "folder")
        )
      ) {
        Text("export_button")
      }
      .foregroundStyle(theme.primaryColor)
    } else {
      Button("export_button") {}
        .disabled(true)
    }

    Button("jump_start_title") {
      model.handleResetPlaybackPosition()
    }

    Button(markTitle) {
      model.handleMarkAsFinished(flag: !areAllFinished)
    }

    if allAreBound {
      Button("bound_books_undo_alert_title") {
        model.updateFolders(model.selectedItems, type: .folder)
      }
    } else {
      Button("bound_books_create_button") {
        if isSingle {
          model.updateFolders(model.selectedItems, type: .bound)
        } else {
          newFolderName = item?.title ?? ""
          newFolderPlaceholder = item?.title ?? ""
          newFolderType = .bound
          showCreateFolderAlert = true
        }
      }
      .disabled(!canCreateBound)
    }

    if let item,
       syncService.isActive
    {
      switch syncService.getDownloadState(for: item) {
      case .notDownloaded:
        Button("download_title") {
          model.startDownload(of: item)
        }
        .disabled(!isSingle)
      case .downloading:
        Button("cancel_download_title") {
          showCancelDownloadAlert = true
        }
        .disabled(!isSingle)
      case .downloaded:
        Button("remove_downloaded_file_title") {
          Task {
            if await syncService.hasUploadTask(for: item.relativePath) {
              showWarningOffloadAlert = true
            } else {
              model.handleOffloading(of: item)
            }
          }
        }
        .disabled(!isSingle)
      }
    }

    Button("delete_button", role: .destructive) {
      showDeleteAlert = true
    }

    Button("cancel_button", role: .cancel) {}
  }
}

// MARK: - Import alert
extension ItemListView {
  private var importOptionsTitle: String {
    let filesCount: Int = importOperationState.alertParameters?.itemIdentifiers.count ?? 0

    return String.localizedStringWithFormat("import_alert_title".localized, filesCount)
  }
  @ViewBuilder
  private func importOptions(
    for alertParameters: ImportOperationState.AlertParameters
  ) -> some View {
    let hasParentFolder = model.libraryNode.folderRelativePath != nil
    let suggestedFolderName = alertParameters.suggestedFolderName ?? ""
    let canCreateBound: Bool = alertParameters.hasOnlyBooks || alertParameters.singleFolder != nil

    if hasParentFolder {
      Button("current_playlist_title") {}
    }

    Button("library_title") {
      if hasParentFolder {
        model.importIntoLibrary(alertParameters.itemIdentifiers)
      }
    }

    Button("new_playlist_button") {
      newFolderName = ""
      newFolderPlaceholder = suggestedFolderName
      newFolderType = .folder
      model.selectedSetItems = Set(alertParameters.itemIdentifiers)
      showCreateFolderAlert = true
    }

    Button("existing_playlist_button") {
      model.selectedSetItems = Set(alertParameters.itemIdentifiers)
      showFoldersSelection = true
    }
    .disabled(alertParameters.availableFolders.isEmpty)

    Button("bound_books_create_button") {
      if alertParameters.hasOnlyBooks {
        newFolderName = ""
        newFolderPlaceholder = suggestedFolderName
        newFolderType = .bound
        model.selectedSetItems = Set(alertParameters.itemIdentifiers)
        showCreateFolderAlert = true
      } else if let singleFolder = alertParameters.singleFolder {
        model.updateFolders([singleFolder], type: .bound)
      }
    }
    .disabled(!canCreateBound)
  }
}

// MARK: - Move alert
extension ItemListView {
  @ViewBuilder
  private func moveOptions() -> some View {
    let availableFolders = model.getAvailableFolders()

    if model.libraryNode != .root {
      Button("library_title") {
        model.handleMoveIntoLibrary()
      }
    }

    Button("new_playlist_button") {
      showCreateFolderAlert = true
    }

    Button("existing_playlist_button") {
      showFoldersSelection = true
    }
    .disabled(availableFolders.isEmpty)
  }
}

// MARK: - Create folder alert
extension ItemListView {
  private var createFolderTitle: LocalizedStringKey {
    newFolderType == .folder
    ? "create_playlist_title"
    : "bound_books_create_alert_title"
  }
  @ViewBuilder
  private func createFolderOptions() -> some View {
    let placeholder = !newFolderPlaceholder.isEmpty
    ? newFolderPlaceholder
    : newFolderType == .folder
    ? "new_playlist_button".localized
    : "bound_books_new_title_placeholder".localized
    let selectedItems = !model.selectedSetItems.isEmpty
    ? Array(model.selectedSetItems).sorted {
      $0.localizedStandardCompare($1) == ComparisonResult.orderedAscending
    }
    : nil

    TextField(
      placeholder,
      text: $newFolderName
    )
    Button("create_button") {
      model.createFolder(
        with: newFolderName,
        items: selectedItems,
        type: newFolderType
      )
      newFolderPlaceholder = ""
      newFolderName = ""
      newFolderType = .folder
    }
    .disabled(newFolderName.isEmpty)
    Button("cancel_button", role: .cancel) {
      newFolderPlaceholder = ""
      newFolderName = ""
      newFolderType = .folder
    }
  }
}

// MARK: - Delete alert
extension ItemListView {
  @ViewBuilder
  private func deleteOptions() -> some View {
    let canShallowDelete = model.selectedItems.count == 1
    && model.selectedItems.first?.type == .folder

    if canShallowDelete {
      Button("delete_deep_button", role: .destructive) {
        model.handleDelete(items: model.selectedItems, mode: .deep)
      }

      Button("delete_shallow_button") {
        model.handleDelete(items: model.selectedItems, mode: .shallow)
      }
    } else {
      Button("delete_button", role: .destructive) {
        model.handleDelete(items: model.selectedItems, mode: .deep)
      }
    }

    Button("cancel_button", role: .cancel) {}
  }
}
