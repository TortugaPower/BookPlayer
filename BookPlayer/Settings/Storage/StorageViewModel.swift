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
  let libraryService: LibraryServiceProtocol
  private let folderURL: URL
  lazy var library: Library = {
    return libraryService.getLibrary()
  }()

  init(libraryService: LibraryServiceProtocol, folderURL: URL) {
    self.libraryService = libraryService
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

        let currentRelativePath = self.getRelativePath(of: fileURL, baseURL: processedFolder)
        let fetchedBook = self.libraryService.getItem(
          with: currentRelativePath
        ) as? Book

        let bookTitle = fetchedBook?.title ?? Book.getBookTitle(from: fileURL)

        let storageItem = StorageItem(
          title: bookTitle,
          fileURL: fileURL,
          path: fileURL.relativePath(to: processedFolder),
          size: fileAttributes[FileAttributeKey.size] as? Int64 ?? 0,
          showWarning: self.shouldShowWarning(for: currentRelativePath, book: fetchedBook)
        )

        items.append(storageItem)
      }

      self.files.value = items
    }
  }

  func getRelativePath(of fileURL: URL, baseURL: URL) -> String {
    return String(fileURL.relativePath(to: baseURL).dropFirst())
  }

  func shouldShowWarning(for relativePath: String, book: Book?) -> Bool {
    guard book == nil else { return false }

    // Fetch may fail with unicode characters, this is a last resort to double check it's not really linked
    return !bookExists(relativePath, library: self.library)
  }

  func bookExists(_ relativePath: String, library: Library) -> Bool {
    guard let items = library.items?.array as? [LibraryItem] else {
      return false
    }

    return items.contains { item in
      if let book = item as? Book {
        return book.relativePath == relativePath
      } else if let folder = item as? Folder {
        return getItem(with: relativePath, from: folder) != nil
      }

      return false
    }
  }

  func getItem(with relativePath: String, from item: LibraryItem) -> LibraryItem? {
    switch item {
    case let folder as Folder:
      return getItem(with: relativePath, from: folder)
    case let book as Book:
      return book.relativePath == relativePath ? book : nil
    default:
      return nil
    }
  }

  func getItem(with relativePath: String, from folder: Folder) -> LibraryItem? {
    guard let items = folder.items?.array as? [LibraryItem] else {
      return nil
    }

    var itemFound: LibraryItem?

    for item in items {
      if let libraryItem = getItem(with: relativePath, from: item) {
        itemFound = libraryItem
        break
      }
    }

    return itemFound
  }

  func reloadLibraryItems() {
    SceneDelegate.shared?.coordinator.getMainCoordinator()?
      .getLibraryCoordinator()?.reloadItemsWithPadding()
  }

  func createBook(from item: StorageItem) throws {
    let book = self.libraryService.createBook(from: item.fileURL)
    try moveBookFile(from: item, with: book)
    try self.libraryService.moveItems([book], inside: nil, moveFiles: false)
    reloadLibraryItems()
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
    var folderSize: Int64 = 0

    let enumerator = FileManager.default.enumerator(
      at: self.folderURL,
      includingPropertiesForKeys: [],
      options: [.skipsHiddenFiles], errorHandler: { (url, error) -> Bool in
        print("directoryEnumerator error at \(url): ", error)
        return true
      })!

    for case let fileURL as URL in enumerator {
      guard let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) else { continue }
      folderSize += fileAttributes[FileAttributeKey.size] as? Int64 ?? 0
    }

    return ByteCountFormatter.string(fromByteCount: folderSize, countStyle: ByteCountFormatter.CountStyle.file)
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
    guard let fetchedBook = self.libraryService.findBooks(containing: item.fileURL)?.first else {
      // create a new book
      try self.createBook(from: item)
      if shouldReloadItems {
        self.loadItems()
      }
      return
    }

    // Relink book object if it's orphaned
    if fetchedBook.getLibrary() == nil {
      try self.libraryService.moveItems([fetchedBook], inside: nil, moveFiles: false)
      reloadLibraryItems()
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
