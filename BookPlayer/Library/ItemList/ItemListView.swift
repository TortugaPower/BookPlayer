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

  @State var activeAlert: ItemListAlert?
  @State var activeSheet: ItemListSheet?
  @State var activeConfirmationDialog: ConfirmationDialogType?
  @State var folderInput = FolderCreationInput()

  @State var showDocumentPicker = false
  @State var downloadURLInput = ""
  @State private var playingItemParentPath: String?

  @Namespace private var customRotorNamespace
  @AccessibilityFocusState private var focus: FocusTarget?

  @Environment(\.libraryService) var libraryService
  @Environment(\.accountService) private var accountService
  @Environment(\.syncService) var syncService
  @Environment(\.hardcoverService) var hardcoverService
  @Environment(\.playerLoaderService) private var playerLoaderService
  @Environment(\.jellyfinService) var jellyfinService
  @Environment(\.listState) var listState
  @Environment(\.playerState) private var playerState
  @Environment(\.loadingState) private var loadingState
  @Environment(\.importOperationState) private var importOperationState
  @Environment(\.scenePhase) private var scenePhase
  @EnvironmentObject private var importManager: ImportManager
  @EnvironmentObject private var theme: ThemeViewModel

  init(initModel: @escaping () -> ItemListViewModel) {
    self._model = .init(wrappedValue: initModel())
  }

  // Computed bindings to help the compiler
  private var isAlertPresented: Binding<Bool> {
    Binding(
      get: { activeAlert != nil },
      set: { if !$0 { activeAlert = nil } }
    )
  }

  private var isConfirmationDialogPresented: Binding<Bool> {
    Binding(
      get: { activeConfirmationDialog != nil },
      set: { if !$0 { activeConfirmationDialog = nil } }
    )
  }

  var body: some View {
    contentView
      .accessibilityFocused($focus, equals: .primary)
      .toolbar {
        mainToolbar()
      }
      .miniPlayerSafeAreaInset()
      .listStyle(.plain)
      .applyListStyle(with: theme, background: theme.systemBackgroundColor)
      .navigationTitle(model.navigationTitle)
  }

  @ViewBuilder
  private var contentView: some View {
    mainContent
      .confirmationDialog(
        activeConfirmationDialog.map { confirmationDialogTitle(for: $0) } ?? "",
        isPresented: isConfirmationDialogPresented,
        titleVisibility: .visible
      ) {
        if let dialog = activeConfirmationDialog {
          confirmationDialogContent(for: dialog)
        }
      }
      .alert(
        alertTitle(for: activeAlert),
        isPresented: isAlertPresented,
        presenting: activeAlert,
        actions: alertContent,
        message: { alert in
          if let message = alertMessage(for: alert) {
            Text(message)
          }
        }
      )
      .sheet(item: $activeSheet) { sheet in
        sheetContent(for: sheet)
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
  }

  @ViewBuilder
  private var mainContent: some View {
    Group {
      if model.isListEmpty {
        EmptyListView(node: model.libraryNode) {
          showDocumentPicker = true
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
          .bpSearchable(
            text: $model.query,
            isSearchFocused: $model.isSearchFocused,
            prompt: "search_title".localized + " \(model.libraryNode.title)",
            selectedScope: $model.scope
          )
          .environment(\.editMode, $model.editMode)
          .refreshable {
            importManager.notifyPendingFiles()
            do {
              try await model.refreshListState()
            } catch {
              self.activeAlert = .queuedTasks
            }
          }
          .environment(\.playingItemParentPath, playingItemParentPath)
          .environment(\.libraryNode, model.libraryNode)
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

        if model.singleFileDownloadService.downloadQueue.count == 0 {
          importOperationState.isOperationActive = false
          importOperationState.processingTitle = ""
        }
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
    .onChange(of: activeAlert) {
      /// Clean up after import completion
      if case .importCompletion = activeAlert {
        // Alert is showing
      } else if importOperationState.alertParameters != nil {
        importOperationState.alertParameters = nil
      }
    }
    .onChange(of: importOperationState.alertParameters) {
      guard
        let alertParameters = importOperationState.alertParameters,
        alertParameters.lastNode == model.libraryNode
      else { return }

      /// Register that at least one import operation has completed
      BPSKANManager.updateConversionValue(.import)
      activeAlert = .importCompletion(alertParameters)
    }
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
        .accessibilityAction {
          guard !model.editMode.isEditing else {
            if model.selectedSetItems.contains(item.id) {
              model.selectedSetItems.remove(item.id)
            } else {
              model.selectedSetItems.insert(item.id)
            }
            return
          }

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
        activeConfirmationDialog = .itemOptions
      } label: {
        Text("options_button")
      }
      Button("delete_button", role: .destructive) {
        model.selectedSetItems = [item.id]
        activeAlert = .delete
      }
      .tint(.red)
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
      activeAlert = .downloadURL("")
    }
    Button("download_from_jellyfin_title", image: .jellyfinIcon) {
      activeSheet = .jellyfin
    }
    Button("create_playlist_button", systemImage: "folder.badge.plus") {
      /// Clean up just in case due to how List(selection:) works under the hood
      model.selectedSetItems.removeAll()
      folderInput.prepareForFolder()
      activeAlert = .createFolder(type: folderInput.type, placeholder: folderInput.placeholder)
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
      activeSheet = .itemDetails(item!)
    } label: {
      Image(systemName: "square.and.pencil")
    }
    .disabled(!isSingle)

    Spacer()

    Button {
      activeAlert = .moveOptions
    } label: {
      Image(systemName: "folder")
    }
    .disabled(model.selectedItems.isEmpty)

    Spacer()

    Button {
      activeAlert = .delete
    } label: {
      Image(systemName: "trash")
    }
    .disabled(model.selectedItems.isEmpty)

    Spacer()

    Button {
      activeConfirmationDialog = .itemOptions
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
    if let item = model.selectedItems.first {
      activeAlert = .cancelDownload(item)
    }
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

  // Helper to unwrap optional alert for title
  private func alertTitle(for alert: ItemListAlert?) -> String {
    guard let alert = alert else { return "" }
    return alertTitle(for: alert)
  }

  // Helper to unwrap optional alert for message
  private func alertMessage(for alert: ItemListAlert?) -> String? {
    guard let alert = alert else { return nil }
    return alertMessage(for: alert)
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
  func itemOptionsDialog() -> some View {
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
      activeSheet = .itemDetails(item!)
    }
    .disabled(!isSingle)
    Button("move_title") {
      activeAlert = .moveOptions
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
          folderInput.prepareForBound(title: item?.title)
          activeAlert = .createFolder(type: folderInput.type, placeholder: folderInput.placeholder)
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
          activeAlert = .cancelDownload(item)
        }
        .disabled(!isSingle)
      case .downloaded:
        Button("remove_downloaded_file_title") {
          Task {
            if await syncService.hasUploadTask(for: item.relativePath) {
              activeAlert = .warningOffload(item)
            } else {
              model.handleOffloading(of: item)
            }
          }
        }
        .disabled(!isSingle)
      }
    }

    Button("delete_button", role: .destructive) {
      activeAlert = .delete
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
