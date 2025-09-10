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
  enum FocusTarget: Hashable { case primary }

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

  @State private var showQueuedTasksAlert = false
  @State private var showQueuedTasks = false

  @State private var playingItemParentPath: String?

  @Namespace private var customRotorNamespace
  @AccessibilityFocusState private var focus: FocusTarget?

  @Environment(\.libraryService) private var libraryService
  @Environment(\.accountService) private var accountService
  @Environment(\.syncService) private var syncService
  @Environment(\.hardcoverService) private var hardcoverService
  @Environment(\.playerLoaderService) private var playerLoaderService
  @Environment(\.jellyfinService) private var jellyfinService
  @Environment(\.listState) private var listState
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
        ScrollViewReader { scrollView in
          List(selection: $model.selectedSetItems) {
            ForEach(model.filteredResults, id: \.id) { item in
              rowView(item)
                .accessibilityRotorEntry(id: item.id, in: customRotorNamespace)
            }
            .onMove { source, destination in
              model.reorderItems(source: source, destination: destination)
            }

            if model.canLoadMore {
              loadMoreView()
            }
          }
          .accessibilityElement(children: .contain)
          .accessibilityRotor("books_title") {
            customBookRotor(with: scrollView)
          }
          .accessibilityRotor("folders_title") {
            customFolderRotor(with: scrollView)
          }
          .searchable(
            text: $model.query,
            isPresented: $model.isSearchFocused,
            prompt: "search_title".localized + " \(model.libraryNode.title)"
          )
          .searchScopes($model.scope) {
            ForEach(ItemListSearchScope.allCases) { scope in
              Text(scope.title).tag(scope)
            }
          }
          .environment(\.editMode, $model.editMode)
          .refreshable {
            importManager.notifyPendingFiles()
            do {
              try await model.refreshListState()
            } catch {
              self.showQueuedTasksAlert = true
            }
          }
          .environment(\.playingItemParentPath, playingItemParentPath)
          .environment(\.libraryNode, model.libraryNode)
        }
      }
    }
    .accessibilityFocused($focus, equals: .primary)
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
      "sync_tasks_inprogress_alert_title",
      isPresented: $showQueuedTasksAlert
    ) {
      Button("sync_tasks_view_title") {
        showQueuedTasks = true
      }
      Button("ok_button", role: .cancel) {}
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
            listState: listState
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
    .task {
      focus = .primary
      await model.syncList()
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
    .onChange(of: listState.token(for: .all), initial: false) {
      let padding = listState.padding(for: .all)
      model.reloadItems(with: padding)
    }
    .onChange(of: listState.token(for: model.reloadScope), initial: false) {
      let padding = listState.padding(for: model.reloadScope)
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
    .sheet(isPresented: $showQueuedTasks) {
      QueuedSyncTasksView()
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
        FolderView(item: item) {
          handleArtworkTap(for: item)
        }
      } else {
        BookView(item: item) {
          handleArtworkTap(for: item)
        }
        .onTapGesture {
          switch syncService.getDownloadState(for: item) {
          case .downloading:
            cancelDownload(of: item.id)
          case .downloaded, .notDownloaded:
            loadPlayer(with: item.relativePath)
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
    .allowsHitTesting(!model.editMode.isEditing)
  }

  @ViewBuilder
  private func loadMoreView() -> some View {
    HStack {
      Spacer()
      ProgressView()
      Spacer()
    }
    .listRowBackground(theme.systemBackgroundColor)
    .accessibilityHidden(true)
    .task { await model.loadNextPage() }
  }

  @ViewBuilder
  private func sortOptions() -> some View {
    Button("title_button", systemImage: "textformat.size") {
      model.handleSort(by: .metadataTitle)
    }
    Button("sort_filename_button", systemImage: "list.bullet.indent") {
      model.handleSort(by: .fileName)
    }
    Button("sort_most_recent_button", systemImage: "clock") {
      model.handleSort(by: .mostRecent)
    }
    Button("sort_reversed_button", systemImage: "repeat") {
      model.handleSort(by: .reverseOrder)
    }
  }

  @ViewBuilder
  private func addFilesOptions() -> some View {
    Button("import_button", systemImage: "waveform") {
      showDocumentPicker = true
    }
    Button("download_from_url_title", systemImage: "link") {
      showDownloadURLAlert = true
    }
    Button("download_from_jellyfin_title", image: .jellyfinIcon) {
      showJellyfin = true
    }
    Button("create_playlist_button", systemImage: "folder.badge.plus") {
      /// Clean up just in case due to how Lis(selection:) works under the hood
      model.selectedSetItems.removeAll()
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
            model.handleSelectAll()
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

      Section {
        sortOptions()
      } header: {
        Text("sort_files_title")
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
    let item = model.selectedItems.first
    let isSingle = model.selectedItems.count == 1

    Spacer()

    Button {
      itemDetailsSelection = item!
    } label: {
      Image(systemName: "square.and.pencil")
    }
    .disabled(!isSingle)

    Spacer()

    Button {
      showMoveOptions = true
    } label: {
      Image(systemName: "folder")
    }
    .disabled(model.selectedItems.isEmpty)

    Spacer()

    Button {
      showDeleteAlert = true
    } label: {
      Image(systemName: "trash")
    }
    .disabled(model.selectedItems.isEmpty)

    Spacer()

    Button {
      showItemOptions = true
    } label: {
      Image(systemName: "ellipsis")
    }
    .disabled(model.selectedItems.isEmpty)

    Spacer()
  }

  private func handleArtworkTap(for item: SimpleLibraryItem) {
    switch syncService.getDownloadState(for: item) {
    case .notDownloaded:
      model.startDownload(of: item)
    case .downloading:
      cancelDownload(of: item.id)
    case .downloaded:
      switch item.type {
      case .folder:
        if let relativePath = model.getNextPlayableBookPath(in: item) {
          loadPlayer(with: relativePath)
        }
      case .bound, .book:
        loadPlayer(with: item.relativePath)
      }
    }
  }

  func cancelDownload(of relativePath: String) {
    model.selectedSetItems = [relativePath]
    showCancelDownloadAlert = true
  }

  func loadPlayer(with relativePath: String) {
    Task {
      do {
        try await playerLoaderService.loadPlayer(relativePath, autoplay: true)
        playerState.showPlayerBinding.wrappedValue = true
      } catch {
        loadingState.error = error
      }
    }
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
  // swiftlint:disable:next function_body_length
  private func itemOptionsDialog() -> some View {
    let item = model.selectedItems.first
    let isSingle = model.selectedItems.count == 1

    let areAllFinished: Bool = model.selectedItems.allSatisfy { $0.isFinished }
    let markTitle: String =
      areAllFinished
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

    Button("cancel_button", role: .cancel) {}
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
    let placeholder =
      !newFolderPlaceholder.isEmpty
      ? newFolderPlaceholder
      : newFolderType == .folder
        ? "new_playlist_button".localized
        : "bound_books_new_title_placeholder".localized
    let selectedItems =
      !model.selectedSetItems.isEmpty
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
    let canShallowDelete =
      model.selectedItems.count == 1
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

// MARK: - Custom Rotors
extension ItemListView {
  @AccessibilityRotorContentBuilder
  private func customBookRotor(with scrollView: ScrollViewProxy) -> some AccessibilityRotorContent {
    ForEach(model.filteredResults, id: \.id) { item in
      if item.type != .folder {
        AccessibilityRotorEntry(
          VoiceOverService.getAccessibilityLabel(for: item),
          item.id,
          in: customRotorNamespace
        ) {
          scrollView.scrollTo(item.id)
        }
      }
    }
  }

  @AccessibilityRotorContentBuilder
  private func customFolderRotor(with scrollView: ScrollViewProxy) -> some AccessibilityRotorContent {
    ForEach(model.filteredResults, id: \.id) { item in
      if item.type == .folder {
        AccessibilityRotorEntry(
          VoiceOverService.getAccessibilityLabel(for: item),
          item.id,
          in: customRotorNamespace
        ) {
          scrollView.scrollTo(item.id)
        }
      }
    }
  }
}
