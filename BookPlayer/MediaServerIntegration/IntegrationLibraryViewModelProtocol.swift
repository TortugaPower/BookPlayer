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
  /// Drives the whole-level download confirmation. List-only screens inherit the
  /// no-op default below so the dialog can never present over them.
  var showingDownloadConfirmation: Bool { get set }
  
  var accountService: AccountService { get set }
  
  var searchQuery: String { get set }
  var isSearchable: Bool { get }

  /// True while the whole-level download is resolving its request list. Drives both the
  /// progress overlay and the disabled state: the loading overlay is a small centred box,
  /// so it only absorbs taps that land on it and cannot guard the toolbar button. The
  /// gating has to be explicit.
  var isPreparingDownload: Bool { get }

  /// Count shown in the whole-level download confirmation. Declared here, not only in the
  /// extension, so a conformer whose download reaches past the loaded page can override it
  /// — an extension-only member would dispatch statically through `Model` and ignore them.
  var downloadableItemCount: Int { get }

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
  /// Stream: virtual-import the level or the selection when the account carries the
  /// entitlement, otherwise open the subscribe flow. Never downloads.
  @MainActor func onStreamTapped(useSelectedItems: Bool)
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
  /// Count for the whole-level download confirmation — what will actually download,
  /// after filtering. Never `totalItems`, which stays `Int.max` until a fetch resolves
  /// and would render as 9223372036854775807 in the dialog.
  var downloadableItemCount: Int {
    items.filter { $0.isDownloadable }.count
  }

  /// Only the Jellyfin folder screen resolves anything before confirming.
  var isPreparingDownload: Bool { false }

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

/// What hydration has to prove about a selected item before it can be imported: a REAL
/// file extension (never guessed) and a length the server actually measured.
///
/// The duration is not cosmetic. It is the only source for an external row's
/// `book.duration` — nothing opens the file, so nothing can measure it later — and
/// `loadChapterOperation` refuses to start playback on a chapter whose duration is 0,
/// silently. An item imported without one is a row that can never play.
struct HydratedItem {
  let fileExtension: String
  let duration: TimeInterval
  /// Whatever chapter list the same payload carried. Optional to an import — an item with
  /// none is still perfectly playable as a single chapter.
  let chapters: [ChapterMetadata]

  /// Both pieces or nothing: a nil result leaves the id out of the hydration map, which
  /// is the pipeline's existing skip contract.
  init?(fileExtension: String?, duration: TimeInterval?, chapters: [ChapterMetadata] = []) {
    guard
      let fileExtension,
      !fileExtension.isEmpty,
      let duration,
      duration > 0
    else { return nil }

    self.fileExtension = fileExtension
    self.duration = duration
    self.chapters = chapters
  }
}

/// Shared orchestration for virtual imports, used by every provider's bulk and
/// details path: hydrate the selection for the values an import can't be built without,
/// build the import payloads, and skip the items that have none. Callers own the
/// `isImporting` reentrancy guard, error surfacing, and staging the result as their
/// `pendingImportBatch`; the two closures carry the only provider-specific parts.
@MainActor
enum VirtualImportPipeline {
  /// - Returns: the import payloads for every item that hydrated, in selection order —
  ///   the caller stages them as its `pendingImportBatch`. Empty means nothing in the
  ///   selection was importable (callers surface the `import_no_audio_files_alert`);
  ///   fewer than `items.count` means the remainder was skipped. The two skip causes —
  ///   no audio-file metadata, no server-measured length — are deliberately not
  ///   distinguished: both mean "this can't be streamed", and neither is actionable
  ///   per-item beyond that one message.
  /// - Throws: hydration/network errors, for the caller's error state.
  static func run<Item>(
    items: [Item],
    id: (Item) -> String,
    hydrate: ([String]) async throws -> [String: HydratedItem],
    buildResource: (Item, HydratedItem) -> SimpleExternalResource
  ) async throws -> [SimpleExternalResource] {
    guard !items.isEmpty else { return [] }

    let hydratedByID = try await hydrate(items.map(id))
    return items.compactMap { item in
      hydratedByID[id(item)].map { buildResource(item, $0) }
    }
  }
}
