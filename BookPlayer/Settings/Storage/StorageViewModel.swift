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

final class StorageViewModel: ObservableObject {
  private var files = CurrentValueSubject<[StorageItem], Never>([])
  private var disposeBag = Set<AnyCancellable>()
  private var library: Library!

  init() {
    self.library = try! DataManager.getLibrary()

    self.loadItems()
  }

  private func loadItems() {
    DispatchQueue.global(qos: .userInteractive).async {
      let processedFolder = DataManager.getProcessedFolderURL()

      let enumerator = FileManager.default.enumerator(
        at: DataManager.getProcessedFolderURL(),
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles], errorHandler: { (url, error) -> Bool in
          print("directoryEnumerator error at \(url): ", error)
          return true
        })!

      var items = [StorageItem]()

      for case let fileURL as URL in enumerator {
        guard !fileURL.isDirectory,
              let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) else { continue }

        let fetchedBook = DataManager.getBook(
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

  public func getLibrarySize() -> String {
    return DataManager.sizeOfItem(at: DataManager.getProcessedFolderURL())
  }

  public func observeFiles() -> AnyPublisher<[StorageItem], Never> {
    self.files.map({ items in
      return items.sorted { $0.size > $1.size }
    }).map({ items in
      return items.sorted { $0.showWarning && !$1.showWarning }
    }).eraseToAnyPublisher()
  }

  public func handleDelete(for item: StorageItem) throws {
    try FileManager.default.removeItem(at: item.fileURL)
  }
}
