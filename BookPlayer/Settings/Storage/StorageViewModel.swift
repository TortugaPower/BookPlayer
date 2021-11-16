//
//  StorageViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 21/8/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import DirectoryWatcher
import Foundation

final class StorageViewModel: BaseViewModel<StorageCoordinator>, ObservableObject {
  private var files = CurrentValueSubject<[StorageItem]?, Never>(nil)
  private var disposeBag = Set<AnyCancellable>()
  private let library: Library
  private let dataManager: DataManager
  private let folderURL: URL

  init(dataManager: DataManager, library: Library, folderURL: URL) {
    self.dataManager = dataManager
    self.library = library
    self.folderURL = folderURL

    super.init()
    self.loadItems()
  }

  private func loadItems() {
    DispatchQueue.global(qos: .userInteractive).async {
      let processedFolder = self.folderURL

      let enumerator = FileManager.default.enumerator(
        at: self.folderURL,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles], errorHandler: { (url, error) -> Bool in
          print("directoryEnumerator error at \(url): ", error)
          return true
        })!

      var items = [StorageItem]()

      for case let fileURL as URL in enumerator {
        guard !fileURL.isDirectoryFolder,
              let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) else { continue }

        let fetchedBook = self.dataManager.getBook(
          with: String(fileURL.relativePath(to: processedFolder).dropFirst()),
          from: self.library
        )

        let bookTitle = fetchedBook?.title ?? Book.getBookTitle(from: fileURL)

        let storageItem = StorageItem(
          title: bookTitle,
          fileURL: fileURL,
          path: fileURL.relativePath(to: processedFolder),
          size: fileAttributes[FileAttributeKey.size] as? Int64 ?? 0,
          showWarning: fetchedBook == nil
        )

        items.append(storageItem)
      }

      self.files.value = items
    }
  }

  private func createBook(from item: StorageItem) throws {
    let book = self.dataManager.createBook(from: item.fileURL)
    try moveBookFile(from: item, with: book)
    self.library.insert(item: book)

    self.dataManager.saveContext()
  }

  private func moveBookFile(from item: StorageItem, with book: Book) throws {
    let isOrphaned = book.getLibrary() == nil
    let defaultDestinationURL = self.folderURL.appendingPathComponent(item.fileURL.lastPathComponent)
    let destinationURL = !isOrphaned
      ? book.fileURL ?? defaultDestinationURL
      : defaultDestinationURL

    guard item.fileURL != destinationURL,
          !FileManager.default.fileExists(atPath: destinationURL.path) else { return }

    // create parent folder if it doesn't exist
    let parentFolder = destinationURL.deletingLastPathComponent()

    if !FileManager.default.fileExists(atPath: parentFolder.path) {
      try FileManager.default.createDirectory(at: parentFolder, withIntermediateDirectories: true, attributes: nil)
    }

    try FileManager.default.moveItem(at: item.fileURL, to: destinationURL)
  }

  public func getLibrarySize() -> String {
    return DataManager.sizeOfItem(at: self.folderURL)
  }

  public func observeFiles() -> AnyPublisher<[StorageItem]?, Never> {
    self.files.map({ items in
      return items?.sorted { $0.size > $1.size }
    }).map({ items in
      return items?.sorted { $0.showWarning && !$1.showWarning }
    }).eraseToAnyPublisher()
  }

  public func handleDelete(for item: StorageItem) throws {
    self.files.value = self.files.value?.filter { $0.fileURL != item.fileURL }

    try FileManager.default.removeItem(at: item.fileURL)
  }

  public func getBrokenItems() -> [StorageItem] {
    return self.files.value?.filter({ $0.showWarning }) ?? []
  }

  public func handleFix(for items: [StorageItem], completion: (() -> Void)) throws {
    guard !items.isEmpty else {
      self.loadItems()
      completion()
      return
    }

    var mutableItems = items

    let currentItem = mutableItems.removeFirst()

    try self.handleFix(for: currentItem, shouldReloadItems: false)

    try self.handleFix(for: mutableItems, completion: completion)
  }

  public func handleFix(for item: StorageItem, shouldReloadItems: Bool = true) throws {
    guard let fetchedBook = self.dataManager.findBooks(containing: item.fileURL)?.first else {
      // create a new book
      try self.createBook(from: item)
      if shouldReloadItems {
        self.loadItems()
      }
      return
    }

    // Relink book object if it's orphaned
    if fetchedBook.getLibrary() == nil {
      self.library.insert(item: fetchedBook)
      self.dataManager.saveContext()
    }

    let fetchedBookURL = self.folderURL.appendingPathComponent(fetchedBook.relativePath)

    // Check if existing book already has its file, and this one is a duplicate
    if FileManager.default.fileExists(atPath: fetchedBookURL.path) {
      try FileManager.default.removeItem(at: item.fileURL)
      self.coordinator.showAlert("storage_duplicate_item_title".localized, message: String.localizedStringWithFormat("storage_duplicate_item_description".localized, fetchedBook.relativePath!))
      if shouldReloadItems {
        self.loadItems()
      }
      return
    }

    try self.moveBookFile(from: item, with: fetchedBook)

    if shouldReloadItems {
      self.loadItems()
    }
  }
}
