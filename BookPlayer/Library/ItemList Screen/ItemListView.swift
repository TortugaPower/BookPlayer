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

  let addAction: () -> Void

  @State private var showItemOptions = false
  @State private var showMoveOptions = false

  @State private var itemDetailsSelection: SimpleLibraryItem?
  @State private var showCreateFolderAlert = false
  @State private var newFolderName: String = ""
  @State private var newFolderType: SimpleItemType = .folder

  @State private var showCancelDownloadAlert = false
  @State private var showWarningOffloadAlert = false

  @State private var showDeleteAlert = false

  @State private var playingItemParentPath: String?

  @Environment(\.libraryService) private var libraryService
  @Environment(\.accountService) private var accountService
  @Environment(\.syncService) private var syncService
  @Environment(\.hardcoverService) private var hardcoverService
  @Environment(\.reloadCenter) private var reloadCenter
  @Environment(\.playerState) private var playerState
  @Environment(\.scenePhase) private var scenePhase
  @EnvironmentObject private var theme: ThemeViewModel

  init(
    initModel: @escaping () -> ItemListViewModel,
    addAction: @escaping () -> Void
  ) {
    self._model = .init(wrappedValue: initModel())
    self.addAction = addAction
  }

  var body: some View {
    Group {
      if model.isListEmpty {
        EmptyListView(
          node: model.libraryNode,
          action: addAction
        )
      } else {
        List {
          ForEach(model.filteredResults, id: \.id) { item in
            ItemView(item: item)
              .onAppear {
                Task {
                  await model.prefetchIfNeeded(for: item)
                }
              }
              .swipeActions(edge: .trailing) {
                Button {
                  model.selectedItems = [item]
                  showItemOptions = true
                } label: {
                  Text("options_button")
                }
              }
          }

          if model.canLoadMore {
            HStack {
              Spacer()
              ProgressView()
              Spacer()
            }
            .task { await model.loadNextPage() }
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
        .onChange(of: playerState.loadedBookRelativePath) {
          playingItemParentPath = model.getPathForParentOfPlayingItem(playerState.loadedBookRelativePath)
        }
      }
    }
    .confirmationDialog(
      model.selectedItems.count == 1
        ? model.selectedItems.first!.title
        : "options_button",
      isPresented: $showItemOptions,
      titleVisibility: .visible
    ) {
      let item = model.selectedItems.first
      let isSingle = model.selectedItems.count == 1

      Button("details_title") {
        itemDetailsSelection = item
      }
      .disabled(!isSingle)
      Button("move_title") {
        showMoveOptions = true
      }

      if model.selectedItems.count == 1,
        let item = model.selectedItems.first
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

      let areFinished = model.selectedItems.filter({ !$0.isFinished }).isEmpty
      let markTitle = areFinished ? "mark_unfinished_title".localized : "mark_finished_title".localized

      Button(markTitle) {
        model.handleMarkAsFinished(flag: !areFinished)
      }

      if model.selectedItems.allSatisfy({ $0.type == .bound }) {
        Button("bound_books_undo_alert_title") {
          model.updateFolders(model.selectedItems, type: .folder)
        }
      } else {
        let isActionEnabled =
          (model.selectedItems.count > 1 && model.selectedItems.allSatisfy({ $0.type == .book }))
          || (isSingle && item?.type == .folder)
        Button("bound_books_create_button") {
          if isSingle {
            model.updateFolders(model.selectedItems, type: .bound)
          } else {
            newFolderName = item?.title ?? ""
            newFolderType = .bound
            showCreateFolderAlert = true
          }
        }
        .disabled(!isActionEnabled)
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
    .alert("choose_destination_title", isPresented: $showMoveOptions) {
      if model.libraryNode != .root {
        Button("library_title") {
          model.handleMoveIntoLibrary()
        }
      }

      Button("new_playlist_button") {
        showCreateFolderAlert = true
      }

      Button("existing_playlist_button") {
        /// show existing folders in sheet, like with details screen
      }
    }
    .alert(
      newFolderType == .folder
        ? "create_playlist_title"
        : "bound_books_create_alert_title",
      isPresented: $showCreateFolderAlert
    ) {
      TextField(
        newFolderType == .folder
          ? "new_playlist_button"
          : "bound_books_new_title_placeholder",
        text: $newFolderName
      )
      Button("create_button") {
        let items =
          !model.selectedItems.isEmpty
          ? model.selectedItems.map { $0.relativePath }
          : nil

        model.createFolder(
          with: newFolderName,
          items: items,
          type: newFolderType
        )
        newFolderName = ""
        newFolderType = .folder
      }
      .disabled(newFolderName.isEmpty)
      Button("cancel_button", role: .cancel) {
        newFolderName = ""
        newFolderType = .folder
      }
    } message: {
      if newFolderType == .bound {
        Text("bound_books_create_alert_description")
      }
    }
    .alert(
      model.deleteActionDetails()?.title ?? "",
      isPresented: $showDeleteAlert
    ) {
      if model.selectedItems.count == 1,
        let item = model.selectedItems.first,
        item.type == .folder
      {
        Button("delete_deep_button", role: .destructive) {
          if model.selectedItems.contains(where: { $0.relativePath == model.playerManager.currentItem?.relativePath }) {
            model.playerManager.stop()
          }
          model.handleDelete(items: model.selectedItems, mode: .deep)
        }

        Button("delete_shallow_button") {
          model.handleDelete(items: model.selectedItems, mode: .shallow)
        }
      } else {
        Button("delete_button", role: .destructive) {
          if model.selectedItems.contains(where: { $0.relativePath == model.playerManager.currentItem?.relativePath }) {
            model.playerManager.stop()
          }
          model.handleDelete(items: model.selectedItems, mode: .deep)
        }
      }

      Button("cancel_button", role: .cancel) {}
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
    .toolbar {
      ToolbarItemGroup(placement: .confirmationAction) {
        if !model.editMode.isEditing {
          regularToolbarTrailing
        } else {
          editingToolbarTrailing
        }
      }

      if model.editMode.isEditing {
        ToolbarItemGroup(placement: .bottomBar) {
          editingBottomBar
        }
      }
    }
    .miniPlayerSafeAreaInset()
    .listStyle(.plain)
    .applyListStyle(with: theme, background: theme.systemBackgroundColor)
    .navigationTitle(model.navigationTitle)
  }

  @ViewBuilder
  var regularToolbarTrailing: some View {
      Button(action: addAction) {
        Image(systemName: "plus")
          .foregroundStyle(theme.linkColor)
      }
      Menu {
        Section {
          Button {
            model.editMode = .active
          } label: {
            Label("select_title".localized, systemImage: "checkmark.circle")
          }
        }
      } label: {
        Label("more_title".localized, systemImage: "ellipsis.circle")
      }
  }

  @ViewBuilder
  var editingToolbarTrailing: some View {
    Button {
      model.editMode = .inactive
      model.selectedItems.removeAll()
    } label: {
      Text("done_title".localized).bold()
    }
  }

  @ViewBuilder
  var editingBottomBar: some View {
    Button {
      if model.selectedItems.isEmpty {
        model.selectedItems = model.items
      } else {
        model.selectedItems.removeAll()
      }
    } label: {
      Image(systemName: model.selectedItems.isEmpty ? "checklist.checked" : "checklist.unchecked")
    }

    Spacer()
  }
}
