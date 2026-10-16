//
//  ImportableItem.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/20/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// A file dropped onto the Library from another app: audio, a video or a zip. Receiving it moves it
/// into Documents, where the import picks it up
struct ImportableItem: Transferable {
  /// Where it now is, in Documents
  let url: URL

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(importedContentType: .audio, importing: moveToDocuments)
    FileRepresentation(importedContentType: .movie, importing: moveToDocuments)
    FileRepresentation(importedContentType: .zip, importing: moveToDocuments)
  }

  /// Under the name it had. Something of that name already there (a file still being imported, or a
  /// folder) is left alone, as the file picker and the share sheet do
  @Sendable
  private static func moveToDocuments(_ received: ReceivedTransferredFile) throws -> ImportableItem {
    let destination = DataManager.getDocumentsFolderURL()
      .appendingPathComponent(received.file.lastPathComponent)

    guard !FileManager.default.fileExists(atPath: destination.path) else {
      return ImportableItem(url: destination)
    }

    /// A copy the system made for this drop can be moved; the sender's own file is copied
    if received.isOriginalFile {
      try FileManager.default.copyItem(at: received.file, to: destination)
    } else {
      try FileManager.default.moveItem(at: received.file, to: destination)
    }
    destination.disableFileProtection()

    return ImportableItem(url: destination)
  }
}

extension View {
  /// Files dropped here from other apps are imported (see `ImportableItem`). On each library screen,
  /// never around them all: on iOS 27.0, a drop destination on any ancestor of the grid's reorder
  /// container (the whole Library tab, or just the grid's scroll view) throws off where a dragged
  /// tile lands
  func acceptsDroppedFiles() -> some View {
    dropDestination(for: ImportableItem.self) { _, _ in }
  }
}
