//
//  StorageViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 21/8/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import DirectoryWatcher
import SwiftUI

protocol StorageViewModelProtocol: ObservableObject {
  var folderURL: URL { get }
  var navigationTitle: String { get }
  var publishedFiles: [StorageItem] { get set }
  var showFixAllButton: Bool { get set }
  var sortBy: BPStorageSortBy { get set }
  var storageAlert: BPStorageAlert { get set }
  var showAlert: Bool { get set }
  var showProgressIndicator: Bool { get set }
  var alert: Alert { get }
  var fixButtonTitle: String { get }

  func getTotalFoldersSize() -> String
  func getArtworkFolderSize() -> String
  func dismiss()
}

enum BPStorageSortBy: Int {
  case size, title
}

enum BPStorageAlert {
  case error(errorMessage: String)
  case delete(item: StorageItem)
  case fix(item: StorageItem)
  case fixAll
  case none // to avoid optional
}

final class StorageViewModel: StorageViewModelProtocol {
  /// Available routes
  enum Routes {
    case showAlert(BPAlertContent)
    case dismiss
  }

  // MARK: - Properties
  let libraryService: LibraryServiceProtocol
  let syncService: SyncServiceProtocol
  let folderURL: URL
  let artworkCacheFolderURL = ArtworkService.cacheDirectoryURL

  @Published var publishedFiles = [StorageItem]() {
    didSet {
      DispatchQueue.main.async {
        self.showFixAllButton = self.publishedFiles.contains { $0.showWarning }
      }
    }
  }
  @Published var showFixAllButton = false
  @Published var showAlert = false
  @Published var showProgressIndicator = false

  @Published var sortBy: BPStorageSortBy {
    didSet {
      publishedFiles = sortedItems(items: publishedFiles)
      UserDefaults.standard.set(sortBy.rawValue, forKey: Constants.UserDefaults.storageFilesSortOrder)
    }
  }

  let navigationTitle = "settings_storage_title".localized
  let fixButtonTitle = "storage_fix_all_title".localized

  var alert: Alert {
    switch storageAlert {
    case .error(let errorMessage):
      return errorAlert(errorMessage)
    case .delete(let item):
      return deleteAlert(for: item)
    case .fix(let item):
      return fixAlert(for: item)
    case .fixAll:
      return fixAllAlert
    case .none:
      // processing this case to use non-optional var for storageAlert.
      // This case should not happen
      return Alert(title: Text(""))
    }
  }

  /// Callback to handle actions on this screen
  var onTransition: BPTransition<Routes>?
  var storageAlert: BPStorageAlert = .none

  lazy var library: Library = {
    libraryService.getLibrary()
  }()

  init(
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol,
    folderURL: URL
  ) {
    self.libraryService = libraryService
    self.syncService = syncService
    self.folderURL = folderURL

    self.sortBy = BPStorageSortBy(rawValue: UserDefaults.standard.integer(forKey: Constants.UserDefaults.storageFilesSortOrder)) ?? .size

    self.loadItems()
  }

  // MARK: - Public interface

  func getTotalFoldersSize() -> String {
    var folderSize: Int64 = 0

    folderSize = getFolderSize(folderURL)
    folderSize += getFolderSize(artworkCacheFolderURL)

    return ByteCountFormatter.string(
      fromByteCount: folderSize,
      countStyle: ByteCountFormatter.CountStyle.file
    )
  }

  func getArtworkFolderSize() -> String {
    let folderSize: Int64 = getFolderSize(artworkCacheFolderURL)

    return ByteCountFormatter.string(
      fromByteCount: folderSize,
      countStyle: ByteCountFormatter.CountStyle.file
    )
  }

  func getFolderSize(_ url: URL) -> Int64 {
    var folderSize: Int64 = 0

    let enumerator = FileManager.default.enumerator(
      at: url,
      includingPropertiesForKeys: [],
      options: [.skipsHiddenFiles], errorHandler: { (url, error) -> Bool in
        print("directoryEnumerator error at \(url): ", error)
        return true
      })!

    for case let fileURL as URL in enumerator {
      guard let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) else { continue }
      folderSize += fileAttributes[FileAttributeKey.size] as? Int64 ?? 0
    }

    return folderSize
  }

  func shouldShowWarning(for relativePath: String) -> Bool {
    // Fetch may fail with unicode characters, this is a last resort to double check it's not really linked
    !bookExists(relativePath, library: self.library)
  }

  func getBrokenItems() -> [StorageItem] {
    publishedFiles.filter({ $0.showWarning })
  }

  func handleFix(for item: StorageItem, shouldReloadItems: Bool = true) throws {
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
      try libraryService.moveItems([fetchedBook.relativePath], inside: nil)
      reloadLibraryItems()
    }

    let fetchedBookURL = self.folderURL.appendingPathComponent(fetchedBook.relativePath)

    // Check if existing book already has its file, and this one is a duplicate
    if FileManager.default.fileExists(atPath: fetchedBookURL.path) {
      try FileManager.default.removeItem(at: item.fileURL)
      if shouldReloadItems {
        let alertMessage = String.localizedStringWithFormat("storage_duplicate_item_description".localized, fetchedBook.relativePath!)
        /// only show alert when doing individual fix
        self.onTransition?(.showAlert(
          BPAlertContent(
            title: "storage_duplicate_item_title".localized,
            message: alertMessage,
            style: .alert,
            actionItems: [
              BPActionItem.okAction
            ]
          )
        ))
        self.loadItems()
      }
      return
    }

    try self.moveBookFile(from: item, with: fetchedBook)

    if shouldReloadItems {
      self.loadItems()
    }
  }

  func deleteSelectedItem(_ item: StorageItem) {
    verifyUploadTask(for: item) { [unowned self] in
      do {
        try handleDelete(for: item)
      } catch {
        storageAlert = .error(errorMessage: error.localizedDescription)
        showAlert = true
      }
    }
  }

  func fixSelectedItem(_ item: StorageItem) {
    do {
      try handleFix(for: item)
    } catch {
      storageAlert = .error(errorMessage: error.localizedDescription)
      showAlert = true
    }
  }

  func fixAllBrokenItems() {
    let brokenItems = getBrokenItems()

    guard !brokenItems.isEmpty else { return }

    showProgressIndicator = true
    do {
      try handleFix(for: brokenItems) { [weak self] in
        self?.showProgressIndicator = false
      }
    } catch {
      showProgressIndicator = false
      storageAlert = .error(errorMessage: error.localizedDescription)
      showAlert = true
    }
  }

  func dismiss() {
    onTransition?(.dismiss)
  }

  // MARK: - Private functions

  private func loadItems() {
    Task { @MainActor in
      showProgressIndicator = true
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
        let fetchedTitle = self.libraryService.getItemProperty(
          #keyPath(BookPlayerKit.LibraryItem.title),
          relativePath: currentRelativePath
        ) as? String

        let bookTitle = fetchedTitle ?? Book.getBookTitle(from: fileURL)

        let storageItem = StorageItem(
          title: bookTitle,
          fileURL: fileURL,
          path: fileURL.relativePath(to: processedFolder),
          size: fileAttributes[FileAttributeKey.size] as? Int64 ?? 0,
          showWarning: fetchedTitle == nil && self.shouldShowWarning(for: currentRelativePath)
        )

        items.append(storageItem)
      }

      showProgressIndicator = false
      self.publishedFiles = self.sortedItems(items: items)
    }
  }

  private func getRelativePath(of fileURL: URL, baseURL: URL) -> String {
    fileURL.relativePath(to: baseURL)
  }

  private func bookExists(_ relativePath: String, library: Library) -> Bool {
    guard let items = library.items?.allObjects as? [BookPlayerKit.LibraryItem] else {
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

  private func getItem(with relativePath: String, from item: BookPlayerKit.LibraryItem) -> BookPlayerKit.LibraryItem? {
    switch item {
    case let folder as Folder:
      return getItem(with: relativePath, from: folder)
    case let book as Book:
      return book.relativePath == relativePath ? book : nil
    default:
      return nil
    }
  }

  private func getItem(with relativePath: String, from folder: Folder) -> BookPlayerKit.LibraryItem? {
    guard let items = folder.items?.allObjects as? [BookPlayerKit.LibraryItem] else {
      return nil
    }

    var itemFound: BookPlayerKit.LibraryItem?

    for item in items {
      if let libraryItem = getItem(with: relativePath, from: item) {
        itemFound = libraryItem
        break
      }
    }

    return itemFound
  }

  private func reloadLibraryItems() {
    AppDelegate.shared?.activeSceneDelegate?.mainCoordinator?
      .getLibraryCoordinator()?.reloadItemsWithPadding()
  }

  private func createBook(from item: StorageItem) throws {
    let book = self.libraryService.createBook(from: item.fileURL)
    try moveBookFile(from: item, with: book)
    try libraryService.moveItems([book.relativePath], inside: nil)
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

  private func sortedItems(items: [StorageItem]) -> [StorageItem] {
    return items
      .sorted { sortBy == .size ? $0.size > $1.size : $0.title < $1.title }
      .sorted { $0.showWarning && !$1.showWarning }
  }

  private func handleDelete(for item: StorageItem) throws {
    try FileManager.default.removeItem(at: item.fileURL)
    let filteredFiles = publishedFiles.filter { $0.fileURL != item.fileURL }
    publishedFiles = self.sortedItems(items: filteredFiles)
  }

  func verifyUploadTask(for item: StorageItem, completionHandler: @escaping () -> Void) {
    Task {
      if await syncService.hasUploadTask(for: item.path) {
        await MainActor.run {
          onTransition?(.showAlert(
            BPAlertContent(
              title: "warning_title".localized,
              message: String(format: "sync_tasks_item_upload_queued".localized, item.path),
              style: .alert,
              actionItems: [
                BPActionItem.cancelAction,
                BPActionItem(title: "Continue", handler: completionHandler)
              ])
          ))
        }
      } else {
        await MainActor.run {
          completionHandler()
        }
      }
    }
  }

  private func handleFix(for items: [StorageItem], completion: @escaping () -> Void) throws {
    guard !items.isEmpty else {
      loadItems()
      completion()
      return
    }

    var mutableItems = items

    let currentItem = mutableItems.removeFirst()

    try handleFix(for: currentItem, shouldReloadItems: false)

    try handleFix(for: mutableItems, completion: completion)
  }

  private var fixAllAlert: Alert {
    Alert(
      title: Text(""),
      message: Text("storage_fix_files_description".localized),
      primaryButton: .cancel(
        Text("cancel_button".localized)
      ),
      secondaryButton: .default(
        Text("storage_fix_file_button".localized),
        action: fixAllBrokenItems
      )
    )
  }

  private func deleteAlert(for item: StorageItem) -> Alert {
    Alert(
      title: Text(""),
      message: Text(String(format: "delete_single_item_title".localized, item.title)),
      primaryButton: .cancel(
        Text("cancel_button".localized)
      ),
      secondaryButton: .destructive(
        Text("delete_button".localized),
        action: { [weak self] in
          self?.deleteSelectedItem(item)
        }
      )
    )
  }

  private func fixAlert(for item: StorageItem) -> Alert {
    Alert(
      title: Text(""),
      message: Text("storage_fix_file_description".localized),
      primaryButton: .cancel(
        Text("cancel_button".localized)
      ),
      secondaryButton: .default(
        Text("storage_fix_file_button".localized),
        action: { [weak self] in
          self?.fixSelectedItem(item)
        }
      )
    )
  }

  private func errorAlert(_ message: String) -> Alert {
    Alert(
      title: Text("error_title".localized),
      message: Text(message),
      dismissButton: .default(Text("ok_button".localized))
    )
  }
}
