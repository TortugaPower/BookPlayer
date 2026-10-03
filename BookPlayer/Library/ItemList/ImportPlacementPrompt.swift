//
//  ImportPlacementPrompt.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

/// What the placement prompt's options do. Each reads where the imported items are when it's
/// picked: they can have moved since the import (into the folder being browsed, or by a sync
/// pull while the prompt waited).
@MainActor
struct ImportPlacementModel {
  let libraryService: LibraryServiceProtocol
  let organizer: LibraryOrganizer

  init(
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol,
    playerManager: PlayerManagerProtocol
  ) {
    self.libraryService = libraryService
    self.organizer = LibraryOrganizer(
      libraryService: libraryService,
      syncService: syncService,
      playerManager: playerManager
    )
  }

  /// The imported items, where they are now
  func items(of placement: ImportPlacement) -> [LibraryItemRef] {
    libraryService.getItemRefs(forUuids: placement.itemUuids)
  }

  /// "Library": out of the folder they were imported into, to the library root
  func moveToLibrary(_ placement: ImportPlacement) throws {
    try organizer.move(items(of: placement), into: nil)
  }

  /// "Existing folder"
  func move(_ placement: ImportPlacement, into folder: SimpleLibraryItem) throws {
    let destination = libraryService.getItemRefs(forUuids: [folder.uuid]).first
      ?? LibraryItemRef(relativePath: folder.relativePath, uuid: folder.uuid)
    try organizer.move(items(of: placement), into: destination)
  }

  /// "New folder", or "Create a volume" for an import of books: a new one holding them, in the
  /// location they were imported into
  func createFolder(titled title: String, for placement: ImportPlacement, type: SimpleItemType) async throws {
    try await organizer.createFolder(
      titled: title,
      inside: placement.node.folderRelativePath,
      holding: items(of: placement),
      type: type
    )
  }

  /// "Create a volume" for an import that was one folder: that folder becomes the volume
  func makeVolume(of placement: ImportPlacement) throws {
    guard
      let uuid = placement.singleFolderUuid,
      let current = libraryService.getItemRefs(forUuids: [uuid]).first,
      let folder = libraryService.getSimpleItem(with: current.relativePath)
    else { return }

    try organizer.convert([folder], to: .bound)
  }
}

/// The "where should these go?" prompt after an import, with its own alert and folder picker.
///
/// Apart from the list's alerts: a prompt SwiftUI drops must not leave the list's alert slot
/// taken (the list's alerts all stopped showing until relaunch). It shows once nothing covers the
/// library (`ListStateManager.coversOnScreen`, the media-server browser and the player) and the
/// Library tab is on screen: a presentation started under either is dropped.
struct ImportPlacementPrompt: ViewModifier {
  let model: ImportPlacementModel
  let importOperationState: ImportOperationState
  let loadingState: LoadingOverlayState
  let isLibraryVisible: Bool

  @Environment(\.listState) private var listState

  /// One alert at a time: the options, then the folder name for "New folder" or "Create a volume"
  enum Stage: Equatable {
    case options(ImportPlacement)
    case name(ImportPlacement, type: SimpleItemType)
  }

  @State private var stage: Stage?
  /// Waiting for the options alert to close before the name alert shows
  @State private var nextStage: Stage?
  @State private var folderPicker: ImportPlacement?
  @State private var folderName = ""

  private var isStagePresented: Binding<Bool> {
    Binding(
      get: { stage != nil },
      set: { if !$0 { stage = nil } }
    )
  }

  func body(content: Content) -> some View {
    content
      .alert(
        stage.map(title(for:)) ?? "",
        isPresented: isStagePresented,
        presenting: stage
      ) { stage in
        switch stage {
        case .options(let placement):
          optionButtons(for: placement)
        case .name(let placement, let type):
          nameField(for: placement, type: type)
        }
      } message: { stage in
        if case .name(_, .bound) = stage {
          Text("bound_books_create_alert_description")
        }
      }
      .sheet(item: $folderPicker, onDismiss: presentIfPossible) { placement in
        ItemListSelectionView(items: placement.availableFolders) { folder in
          perform(on: placement) { try model.move(placement, into: folder) }
        }
      }
      .onChange(of: importOperationState.pendingPlacement) { presentIfPossible() }
      .onChange(of: listState.coversOnScreen) { presentIfPossible() }
      .onChange(of: isLibraryVisible) { presentIfPossible() }
      .onChange(of: stage) {
        // An import that finished while this prompt showed gets its own turn
        if stage == nil, nextStage == nil {
          presentIfPossible()
        }
      }
  }

  private func presentIfPossible() {
    guard
      stage == nil,
      nextStage == nil,
      folderPicker == nil,
      let placement = importOperationState.pendingPlacement,
      listState.coversOnScreen.isEmpty,
      isLibraryVisible
    else { return }

    importOperationState.pendingPlacement = nil
    /// Register that at least one import operation has completed
    BPSKANManager.updateConversionValue(.import)
    stage = .options(placement)
  }

  /// The next alert, once this one has closed
  private func show(_ next: Stage) {
    nextStage = next
    stage = nil
    Task { @MainActor in
      stage = nextStage
      nextStage = nil
    }
  }

  private func title(for stage: Stage) -> String {
    switch stage {
    case .options(let placement):
      return String.localizedStringWithFormat("import_alert_title".localized, placement.itemUuids.count)
    case .name(_, let type):
      return type == .folder
        ? "create_playlist_title".localized
        : "bound_books_create_alert_title".localized
    }
  }

  @ViewBuilder
  private func optionButtons(for placement: ImportPlacement) -> some View {
    let hasParentFolder = placement.node.folderRelativePath != nil
    let suggestedFolderName = ((placement.suggestedFolderName ?? "") as NSString).deletingPathExtension

    if hasParentFolder {
      Button("current_playlist_title") {}
    }

    Button("library_title") {
      if hasParentFolder {
        perform(on: placement) { try model.moveToLibrary(placement) }
      }
    }

    Button("new_playlist_button") {
      folderName = suggestedFolderName
      show(.name(placement, type: .folder))
    }

    Button("existing_playlist_button") {
      folderPicker = placement
    }
    .disabled(placement.availableFolders.isEmpty)

    Button("bound_books_create_button") {
      if placement.hasOnlyBooks {
        folderName = suggestedFolderName
        show(.name(placement, type: .bound))
      } else {
        perform(on: placement) { try model.makeVolume(of: placement) }
      }
    }
    .disabled(!placement.hasOnlyBooks && placement.singleFolderUuid == nil)
  }

  @ViewBuilder
  private func nameField(for placement: ImportPlacement, type: SimpleItemType) -> some View {
    let suggestedFolderName = ((placement.suggestedFolderName ?? "") as NSString).deletingPathExtension
    let placeholder = !suggestedFolderName.isEmpty
      ? suggestedFolderName
      : type == .folder
        ? "new_playlist_button".localized
        : "bound_books_new_title_placeholder".localized

    TextField(placeholder, text: $folderName)

    Button("create_button") {
      let title = folderName
      Task { @MainActor in
        do {
          try await model.createFolder(titled: title, for: placement, type: type)
          listState.reloadAll(padding: 1)
        } catch {
          loadingState.error = error
        }
      }
    }
    .disabled(folderName.isEmpty)

    Button("cancel_button", role: .cancel) {}
  }

  private func perform(on placement: ImportPlacement, _ action: () throws -> Void) {
    do {
      try action()
    } catch {
      loadingState.error = error
    }

    listState.reloadAll(padding: placement.itemUuids.count)
  }
}
