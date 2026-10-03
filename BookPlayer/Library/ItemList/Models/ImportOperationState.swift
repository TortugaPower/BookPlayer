//
//  ImportOperationState.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 28/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

@Observable
final class ImportOperationState {
  var processingTitle = ""
  var isOperationActive = false
  /// A finished import waiting for its placement prompt (`ImportPlacementPrompt`)
  var pendingPlacement: ImportPlacement?
}

/// What the "where should these go?" prompt offers for a finished import.
///
/// Identifies the imported items by uuid: they can move before the user picks an option (into
/// the folder being browsed, or by a sync pull while the prompt waits), so their current paths
/// are read when an option is picked.
struct ImportPlacement: Equatable, Identifiable {
  let id = UUID()
  let itemUuids: [String]
  let hasOnlyBooks: Bool
  /// The import's only item, when it's a folder: "Create a volume" turns it into one
  let singleFolderUuid: String?
  /// Folders the items can move into, in the location they were imported into
  let availableFolders: [SimpleLibraryItem]
  let suggestedFolderName: String?
  /// The location the import landed in
  let node: LibraryNode
}
