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
  var alertParameters: AlertParameters?

  struct AlertParameters: Equatable {
    var itemIdentifiers: [String]
    var hasOnlyBooks: Bool
    var singleFolder: SimpleLibraryItem?
    var availableFolders: [SimpleLibraryItem]
    var suggestedFolderName: String?
    var lastNode: LibraryNode
  }
}
