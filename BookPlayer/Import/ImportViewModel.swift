//
//  ImportViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 23/6/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import DirectoryWatcher
import Foundation

final class ImportViewModel: ObservableObject {
  @Published private(set) var files = [FileItem]()
  private var disposeBag = Set<AnyCancellable>()
  private let importManager: ImportManager
  private var watchers = [DirectoryWatcher]()
  private var observedFiles = [FileItem]()

  init(importManager: ImportManager = ImportManager.shared) {
    self.importManager = importManager

    self.bindInternalFiles()
  }

  private func bindInternalFiles() {
    ImportManager.shared.observeFiles().sink { [weak self] files in
      guard let self = self else { return }

      self.cleanupWatchters()
      // make a copy of the files
      self.observedFiles = files.map({ FileItem(originalUrl: $0, destinationFolder: $0) })
      self.subscribeNewFolders()
      self.refreshData()
    }.store(in: &disposeBag)
  }

  private func cleanupWatchters() {
    self.watchers.forEach({ _ = $0.stopWatching() })
    self.watchers = []
  }

  private func subscribeNewFolders() {
    for file in self.observedFiles {
      guard file.originalUrl.isDirectory else { continue }

      let enumerator = FileManager.default.enumerator(at: file.originalUrl,
                                                      includingPropertiesForKeys: [.isDirectoryKey],
                                                      options: [.skipsHiddenFiles], errorHandler: { (url, error) -> Bool in
                                                        print("directoryEnumerator error at \(url): ", error)
                                                        return true
                                                      })!

      for case let fileURL as URL in enumerator {
        if !fileURL.isDirectory {
          file.subItems += 1
        } else if !self.watchers.contains(where: { $0.watchedUrl == fileURL }) {
          let watcher = DirectoryWatcher(watchedUrl: fileURL)
          self.watchers.append(watcher)

          watcher.onNewFiles = { [weak self] newFiles in
            guard let self = self else { return }
            file.subItems += newFiles.count
            self.refreshData()
          }

          _ = watcher.startWatching()
        }
      }
    }
  }

  private func refreshData() {
    self.files = self.observedFiles
  }

  public func getTotalItems() -> Int {
    return self.files.reduce(0) { result, file in
      return file.originalUrl.isDirectory
        ? result + file.subItems
        : result + 1
    }
  }

  public func deleteItem(_ item: URL) throws {
    try ImportManager.shared.removeFile(item)
  }

  public func discardImportOperation() throws {
    try ImportManager.shared.removeAllFiles()
  }

  public func createOperation() {
    ImportManager.shared.createOperation()
  }
}
