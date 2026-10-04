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

  /// "Existing folder". Nothing happens when the folder is gone (a sync pull deleted it while the
  /// prompt waited): moving into its old path would leave the items' paths pointing nowhere.
  func move(_ placement: ImportPlacement, into folder: SimpleLibraryItem) throws {
    guard let destination = libraryService.getItemRefs(forUuids: [folder.uuid]).first else { return }

    try organizer.move(items(of: placement), into: destination)
  }

  /// "New folder", or "Create a volume" for an import of books: a new one holding them, in the
  /// folder they were imported into, wherever it is now. Nothing happens when that folder is gone.
  func createFolder(titled title: String, for placement: ImportPlacement, type: SimpleItemType) async throws {
    let parentPath: String?
    if placement.node.folderRelativePath != nil {
      guard let parent = libraryService.getItemRefs(forUuids: [placement.node.uuid]).first else { return }
      parentPath = parent.relativePath
    } else {
      parentPath = nil
    }

    try await organizer.createFolder(
      titled: title,
      inside: parentPath,
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
/// library (the media-server browser, the player, the import screen) and the Library tab is on
/// screen: a presentation started under either is dropped. What the list itself presents isn't
/// waited for: the prompt closes it (seen with a sheet), or is dropped under it, lost, and cleared
/// before the next import's.
struct ImportPlacementPrompt: ViewModifier {
  let model: ImportPlacementModel
  let importOperationState: ImportOperationState
  let loadingState: LoadingOverlayState
  let isLibraryVisible: Bool
  let isImportScreenShown: Bool

  @Environment(\.listState) private var listState

  /// The folder name asked for after "New folder" or "Create a volume"
  struct NameRequest: Equatable {
    let placement: ImportPlacement
    let type: SimpleItemType
  }

  @State private var options: ImportPlacement?
  @State private var nameRequest: NameRequest?
  @State private var folderPicker: ImportPlacement?
  @State private var folderName = ""

  /// Nothing of the prompt's counts as on screen
  private var isIdle: Bool {
    options == nil && nameRequest == nil && folderPicker == nil
  }

  /// What decides when the prompt shows, watched as one value: with a single handler, the clear
  /// when the import screen closes always runs before presenting
  private struct Gate: Equatable {
    let pendingPlacement: UUID?
    let isCovered: Bool
    let isImportScreenShown: Bool
    let isLibraryVisible: Bool

    var isOpen: Bool { !isCovered && !isImportScreenShown && isLibraryVisible }
  }

  private var gate: Gate {
    Gate(
      pendingPlacement: importOperationState.pendingPlacement?.id,
      // Only covers that appeared: one requested but dropped by iOS never appears or dismisses,
      // so counting requests would hold every later prompt. The request-to-appear window is a frame
      isCovered: !listState.coversOnScreen.isEmpty,
      isImportScreenShown: isImportScreenShown,
      isLibraryVisible: isLibraryVisible
    )
  }

  func body(content: Content) -> some View {
    content
      .alert(
        options.map { String.localizedStringWithFormat("import_alert_title".localized, $0.itemUuids.count) } ?? "",
        isPresented: Binding(get: { options != nil }, set: { if !$0 { options = nil } }),
        presenting: options
      ) { placement in
        optionButtons(for: placement)
      }
      // The name alert is a separate presentation, on its own view: set from an option while the
      // options alert closes, SwiftUI shows it once that one is gone. Switching one alert's
      // contents instead (nil, then the next) was dropped mid-animation
      .background {
        Color.clear
          .alert(
            nameRequest.map { $0.type == .folder ? "create_playlist_title".localized : "bound_books_create_alert_title".localized } ?? "",
            isPresented: Binding(get: { nameRequest != nil }, set: { if !$0 { nameRequest = nil } }),
            presenting: nameRequest
          ) { request in
            nameField(for: request.placement, type: request.type)
          } message: { request in
            if request.type == .bound {
              Text("bound_books_create_alert_description")
            }
          }
      }
      .sheet(item: $folderPicker) { placement in
        ItemListSelectionView(items: placement.availableFolders) { folder in
          perform(on: placement) { try model.move(placement, into: folder) }
        }
      }
      .onChange(of: gate) { old, new in
        if old.isImportScreenShown, !new.isImportScreenShown {
          clearBeforeTheNextImport()
        }
        presentIfPossible()
      }
  }

  /// Every import is confirmed on the import screen, so this runs before each import's prompt
  /// comes. An alert doesn't report appearing: one iOS dropped (presented under something the list
  /// showed) still counts as on screen, and would block every later prompt. One that really is on
  /// screen, with the import screen opened over it, closes.
  ///
  /// Rare, with two imports processing at once: an earlier import's prompt can be waiting when
  /// this clears one. Set in the same update, SwiftUI takes it for the cleared one's contents
  /// changing, so if that one was dropped this doesn't show either (and is cleared at the next
  /// close). Set a pass later, it would be dropped instead whenever the cleared one really showed
  /// and is still closing.
  private func clearBeforeTheNextImport() {
    options = nil
    nameRequest = nil
    folderPicker = nil
  }

  private func presentIfPossible() {
    guard
      let placement = importOperationState.pendingPlacement,
      gate.isOpen
    else { return }

    importOperationState.pendingPlacement = nil
    /// Register that at least one import operation has completed
    BPSKANManager.updateConversionValue(.import)

    /// A second import finishing while this prompt shows: its prompt is dropped
    guard isIdle else { return }

    options = placement
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
      nameRequest = NameRequest(placement: placement, type: .folder)
    }

    Button("existing_playlist_button") {
      folderPicker = placement
    }
    .disabled(placement.availableFolders.isEmpty)

    Button("bound_books_create_button") {
      if placement.hasOnlyBooks {
        folderName = suggestedFolderName
        nameRequest = NameRequest(placement: placement, type: .bound)
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
