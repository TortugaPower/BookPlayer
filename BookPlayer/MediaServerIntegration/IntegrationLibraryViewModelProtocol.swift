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
  /// Staged virtual-import selection awaiting confirmation (`.sheet(item:)`);
  /// nil on the list-only screens that never import.
  var pendingImportBatch: ExternalImportBatch? { get set }
  /// Hands the confirmed (possibly edited) selection to the import bus.
  @MainActor func confirmExternalImport(_ resources: [SimpleExternalResource])
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
/// build the import payloads, and skip items without audio-file metadata. Callers
/// own the `isImporting` reentrancy guard, error surfacing, and staging the result
/// as their `pendingImportBatch`; the two closures carry the only
/// provider-specific parts.
@MainActor
enum VirtualImportPipeline {
  /// - Returns: the import payloads for every item whose REAL file extension could
  ///   be hydrated, in selection order — the caller stages them as its
  ///   `pendingImportBatch`. Empty means nothing in the selection had audio-file
  ///   metadata (callers surface the `import_no_audio_files_alert`); fewer than
  ///   `items.count` means the remainder was skipped.
  /// - Throws: hydration/network errors, for the caller's error state.
  static func run<Item>(
    items: [Item],
    id: (Item) -> String,
    hydrateExtensions: ([String]) async throws -> [String: String],
    buildResource: (Item, String) -> SimpleExternalResource
  ) async throws -> [SimpleExternalResource] {
    guard !items.isEmpty else { return [] }

    let extensionsByID = try await hydrateExtensions(items.map(id))
    return items.compactMap { item in
      extensionsByID[id(item)].map { buildResource(item, $0) }
    }
  }
}
