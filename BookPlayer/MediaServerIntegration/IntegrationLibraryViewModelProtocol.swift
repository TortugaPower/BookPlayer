//
//  IntegrationLibraryViewModelProtocol.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import BookPlayerKit

enum IntegrationLayout {
  enum Options: String {
    case grid, list
  }
}

@MainActor
protocol IntegrationLibraryViewModelProtocol: ObservableObject {
  associatedtype Item: IntegrationLibraryItemProtocol
  associatedtype Destination: Hashable

  var navigation: BPNavigation { get set }
  var navigationTitle: String { get }
  var layout: IntegrationLayout.Options { get set }

  var items: [Item] { get set }
  var totalItems: Int { get }
  var error: Error? { get set }

  var editMode: EditMode { get set }
  var selectedItems: Set<Item.ID> { get set }
  var showingDownloadConfirmation: Bool { get set }
  var useSelectedItems: Bool { get set }
  
  var importManager: ImportManager { get set }
  var accountService: AccountService { get set }
  
  var searchQuery: String { get set }
  var isSearchable: Bool { get }

  // Feature flags (defaults provided)
  var isGridEnabled: Bool { get }
  var showsLayoutPreferences: Bool { get }
  var showsSortPreferences: Bool { get }
  var allowsEditing: Bool { get }

  func fetchInitialItems()
  func fetchMoreItemsIfNeeded(currentItem: Item)
  func cancelFetchItems()
  func destination(for item: Item) -> Destination?

  @MainActor func handleDoneAction()
  @MainActor func onEditToggleSelectTapped()
  @MainActor func onSelectTapped(for item: Item)
  @MainActor func onSelectAllTapped()
  @MainActor func handleImportItems(useSelectedItems: Bool) async
  @MainActor func onDownloadTapped()
  @MainActor func onDownloadFolderTapped()
  @MainActor func confirmDownloadFolder()
  @MainActor func goToSubscribe()
}

extension IntegrationLibraryViewModelProtocol {
  var isGridEnabled: Bool { true }
  var showsLayoutPreferences: Bool { true }
  var showsSortPreferences: Bool { true }
  var allowsEditing: Bool { true }
  var showingDownloadConfirmation: Bool {
    get { false }
    set {}
  }
}

// MARK: - Virtual import pipeline

/// Shared orchestration for virtual imports, used by every provider's bulk and
/// details path: hydrate the selection for REAL file extensions (never guessed),
/// build the import payloads, skip items without audio-file metadata, and hand
/// the batch to the import sheet. Callers own the `isImporting` reentrancy guard
/// and error surfacing; the two closures carry the only provider-specific parts.
@MainActor
enum VirtualImportPipeline {
  /// - Returns: the number of items handed to the import sheet. Zero means
  ///   nothing in the selection had audio-file metadata (callers surface the
  ///   `import_no_audio_files_alert`); a value below `items.count` means the
  ///   remainder was skipped.
  /// - Throws: hydration/network errors, for the caller's error state.
  static func run<Item>(
    items: [Item],
    id: (Item) -> String,
    hydrateExtensions: ([String]) async throws -> [String: String],
    buildResource: (Item, String) -> SimpleExternalResource,
    importManager: ImportManager,
    beforePresenting: (() -> Void)? = nil
  ) async throws -> Int {
    guard !items.isEmpty else { return 0 }

    let extensionsByID = try await hydrateExtensions(items.map(id))
    let resources = items.compactMap { item in
      extensionsByID[id(item)].map { buildResource(item, $0) }
    }
    guard !resources.isEmpty else { return 0 }

    beforePresenting?()
    importManager.externalFiles.append(contentsOf: resources)
    importManager.isShowingExternalImportView = true
    return resources.count
  }
}
