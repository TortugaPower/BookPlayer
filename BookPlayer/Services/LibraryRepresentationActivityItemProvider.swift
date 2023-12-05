//
//  LibraryRepresentationActivityItemProvider.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 28/11/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation

final class LibraryRepresentationActivityItemProvider: UIActivityItemProvider {
  let libraryRepresentation: String

  init(libraryRepresentation: String) {
    self.libraryRepresentation = libraryRepresentation
    super.init(placeholderItem: URL(fileURLWithPath: "placeholder.txt"))
  }

  public override func activityViewController(
    _ activityViewController: UIActivityViewController,
    itemForActivityType activityType: UIActivity.ActivityType?
  ) -> Any? {
    let fileTitle = "library_hierarchy_tree.txt"
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileTitle)

    do {
      if FileManager.default.fileExists(atPath: fileURL.path) {
        try FileManager.default.removeItem(at: fileURL)
      }

      let contentsData = libraryRepresentation.data(using: .utf8)
      FileManager.default.createFile(atPath: fileURL.path, contents: contentsData)
    } catch {
      return nil
    }

    return fileURL
  }

  public override func activityViewControllerPlaceholderItem(
    _ activityViewController: UIActivityViewController
  ) -> Any {
    return URL(fileURLWithPath: "placeholder.txt")
  }
}
