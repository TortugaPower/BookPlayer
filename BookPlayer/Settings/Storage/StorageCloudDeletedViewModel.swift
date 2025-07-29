//
//  StorageCloudDeletedViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 10/7/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation
import SwiftUI

protocol StorageCloudDeletedViewModelProtocol: ObservableObject {
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

  func getFolderSize() -> String
  func dismiss()
}

final class StorageCloudDeletedViewModel: StorageCloudDeletedViewModelProtocol {  
  /// Available routes
  enum Routes {
    case showAlert(title: String, message: String)
    case dismiss
  }

  /// Screen navigation title
  let navigationTitle = "Files"
  /// Fix-all button title
  let fixButtonTitle = "import_button".localized

  /// List of files to be listed
  @Published var publishedFiles = [StorageItem]() {
    didSet {
      self.showFixAllButton = !self.publishedFiles.isEmpty
    }
  }
  /// Sort option selected
  @Published var sortBy: BPStorageSortBy {
    didSet {
      publishedFiles = sortedItems(items: publishedFiles)
    }
  }

  /// In-memory alert to show
  var storageAlert: BPStorageAlert = .none
  @Published var showFixAllButton: Bool = false
  @Published var showAlert: Bool = false
  @Published var showProgressIndicator: Bool = false

  var onTransition: BPTransition<Routes>?

  var alert: Alert {
    switch storageAlert {
    case .error(let errorMessage):
      return errorAlert(errorMessage)
    case .delete(let item):
      return deleteAlert(for: item)
    case .fixAll:
      return fixAllAlert
    case .none, .fix, .uploadTask:
      return Alert(title: Text(""))
    }
  }

  let folderURL: URL

  init(folderURL: URL) {
    self.folderURL = folderURL

    self.sortBy = BPStorageSortBy(rawValue: UserDefaults.standard.integer(forKey: Constants.UserDefaults.storageFilesSortOrder)) ?? .size

    self.loadItems()
  }

  func dismiss() {
    onTransition?(.dismiss)
  }

  func getFolderSize() -> String {
    var folderSize: Int64 = 0

    let enumerator = FileManager.default.enumerator(
      at: folderURL,
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

  private func loadItems() {
    showProgressIndicator = true
    Task { @MainActor in
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
        guard
          !fileURL.isDirectoryFolder,
          let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        else { continue }

        let bookTitle = Book.getBookTitle(from: fileURL)

        let storageItem = StorageItem(
          title: bookTitle,
          fileURL: fileURL,
          path: fileURL.relativePath(to: processedFolder),
          size: fileAttributes[FileAttributeKey.size] as? Int64 ?? 0,
          showWarning: false
        )

        items.append(storageItem)
      }

      showProgressIndicator = false
      self.publishedFiles = self.sortedItems(items: items)
    }
  }

  private func sortedItems(items: [StorageItem]) -> [StorageItem] {
    return items.sorted {
      sortBy == .size
      ? $0.size > $1.size
      : $0.title < $1.title
    }
  }

  private var fixAllAlert: Alert {
    Alert(
      title: Text(""),
      message: Text("storage_sync_deleted_recover_description".localized),
      primaryButton: .cancel(
        Text("cancel_button".localized)
      ),
      secondaryButton: .default(
        Text("import_button".localized),
        action: moveAllFiles
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

  private func errorAlert(_ message: String) -> Alert {
    Alert(
      title: Text("error_title".localized),
      message: Text(message),
      dismissButton: .default(Text("ok_button".localized))
    )
  }

  func deleteSelectedItem(_ item: StorageItem) {
    do {
      try FileManager.default.removeItem(at: item.fileURL)
      let filteredFiles = publishedFiles.filter { $0.fileURL != item.fileURL }
      publishedFiles = self.sortedItems(items: filteredFiles)
    } catch {
      storageAlert = .error(errorMessage: error.localizedDescription)
      showAlert = true
    }
  }

  func moveAllFiles() {
    do {
      /// Perform shallow search to only move the root items to the documents folder for the import process
      let items = try FileManager.default.contentsOfDirectory(atPath: folderURL.path)

      let documentsFolderURL = DataManager.getDocumentsFolderURL()

      for item in items {
        let originURL = folderURL.appendingPathComponent(item)
        let destinationURL = documentsFolderURL.appendingPathComponent(item)

        try FileManager.default.moveItem(at: originURL, to: destinationURL)
      }

      publishedFiles = []
    } catch {
      storageAlert = .error(errorMessage: error.localizedDescription)
      showAlert = true
    }
  }
}
