//
//  IntegrationLibraryViewModelProtocol.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

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

  var searchQuery: String { get set }
  var isSearchable: Bool { get }

  // Feature flags (defaults provided)
  var isGridEnabled: Bool { get }
  var showsLayoutPreferences: Bool { get }
  var showsSortPreferences: Bool { get }
  var allowsEditing: Bool { get }
  var showingDownloadConfirmation: Bool { get set }

  func fetchInitialItems()
  func fetchMoreItemsIfNeeded(currentItem: Item)
  func cancelFetchItems()
  func destination(for item: Item) -> Destination?

  @MainActor func handleDoneAction()
  @MainActor func onEditToggleSelectTapped()
  @MainActor func onSelectTapped(for item: Item)
  @MainActor func onSelectAllTapped()
  @MainActor func onDownloadTapped()
  @MainActor func onDownloadFolderTapped()
  @MainActor func confirmDownloadFolder()
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
  func onDownloadFolderTapped() {}
  func confirmDownloadFolder() {}
}
