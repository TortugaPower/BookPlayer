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
  let libraryService: LibraryServiceProtocol

  init(libraryService: LibraryServiceProtocol) {
    self.libraryService = libraryService
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

      let libraryRepresentation = getLibraryRepresentation()
      let contentsData = libraryRepresentation.data(using: .utf8)
      FileManager.default.createFile(atPath: fileURL.path, contents: contentsData)
    } catch {
      return nil
    }

    return fileURL
  }

  /// Get a representation of the library like with the `tree` command
  /// Note: '✓' means the backing file exists, and '𐄂' that it's missing locally
  private func getLibraryRepresentation() -> String {
    let contents = libraryService.fetchRawContents(
      at: nil,
      propertiesToFetch: [
        #keyPath(LibraryItem.relativePath),
        #keyPath(LibraryItem.type)
      ]
    ) ?? []

    var libraryRepresentation = ".\n"
    let processedFolderURL = DataManager.getProcessedFolderURL()

    for (index, item) in contents.enumerated() {
      let itemRepresentation: String

      switch item.type {
      case .book:
        itemRepresentation = processBookRepresentation(
          item.relativePath,
          isLast: index == (contents.endIndex - 1),
          processedFolderURL: processedFolderURL
        )
      case .folder, .bound:
        itemRepresentation = processFolderRepresentation(
          item.relativePath,
          nestedLevel: 0,
          processedFolderURL: processedFolderURL
        )
      }

      libraryRepresentation += itemRepresentation + "\n"
    }

    return libraryRepresentation
  }

  private func processFolderRepresentation(
    _ relativePath: String,
    nestedLevel: Int,
    processedFolderURL: URL
  ) -> String {
    let contents = libraryService.fetchRawContents(
      at: relativePath,
      propertiesToFetch: [
        #keyPath(LibraryItem.relativePath),
        #keyPath(LibraryItem.type)
      ]
    ) ?? []

    let fileURL = processedFolderURL.appendingPathComponent(relativePath)
    let fileExistsRepresentation = FileManager.default.fileExists(atPath: fileURL.path)
    ? "✓"
    : "𐄂"

    let baseSeparator = "|   "
    var horizontalSeparator = String(repeating: baseSeparator, count: nestedLevel)
    var folderRepresentation = horizontalSeparator + "`-- \(fileURL.lastPathComponent) \(fileExistsRepresentation)"
    horizontalSeparator += baseSeparator

    if !contents.isEmpty {
      folderRepresentation += "\n"
    }

    for (index, item) in contents.enumerated() {
      let itemRepresentation: String
      let isLast = index == (contents.endIndex - 1)

      switch item.type {
      case .book:
        let bookRepresentation = processBookRepresentation(
          item.relativePath,
          isLast: isLast,
          processedFolderURL: processedFolderURL
        )

        itemRepresentation = horizontalSeparator + bookRepresentation
      case .folder, .bound:
        itemRepresentation = processFolderRepresentation(
          item.relativePath,
          nestedLevel: nestedLevel + 1,
          processedFolderURL: processedFolderURL
        )
      }

      if isLast {
        folderRepresentation += itemRepresentation
      } else {
        folderRepresentation += itemRepresentation + "\n"
      }
    }

    return folderRepresentation
  }

  private func processBookRepresentation(
    _ relativePath: String,
    isLast: Bool,
    processedFolderURL: URL
  ) -> String {
    let fileURL = processedFolderURL.appendingPathComponent(relativePath)
    let fileExistsRepresentation = FileManager.default.fileExists(atPath: fileURL.path)
    ? "✓"
    : "𐄂"

    if isLast {
      return "`-- \(fileURL.lastPathComponent) \(fileExistsRepresentation)"
    } else {
      return "|-- \(fileURL.lastPathComponent) \(fileExistsRepresentation)"
    }
  }

  public override func activityViewControllerPlaceholderItem(
    _ activityViewController: UIActivityViewController
  ) -> Any {
    return URL(fileURLWithPath: "placeholder.txt")
  }
}
