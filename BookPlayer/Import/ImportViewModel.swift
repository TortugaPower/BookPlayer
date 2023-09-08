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

final class ImportViewModel: ViewModelProtocol, ObservableObject {

  weak var coordinator: ImportCoordinator!
  @Published private(set) var files = [ImportFileItem]()
  private var disposeBag = Set<AnyCancellable>()
  private let importManager: ImportManager
  private var watchers = [DirectoryWatcher]()
  private var observedFiles = [ImportFileItem]()

  init(importManager: ImportManager) {
    self.importManager = importManager
    self.bindInternalFiles()
  }

  private func bindInternalFiles() {
    self.importManager.observeFiles().sink { [weak self] files in
      guard let self = self else { return }

      self.cleanupWatchters()
      // make a copy of the files
      self.observedFiles = files.map { ImportFileItem(fileUrl: $0) }
      self.subscribeNewFolders()
      self.refreshData()
    }.store(in: &disposeBag)
  }

  private func cleanupWatchters() {
    self.watchers.forEach({ _ = $0.stopWatching() })
    self.watchers = []
  }

  private func subscribeNewFolders() {
    for item in self.observedFiles {
      guard item.fileUrl.isDirectoryFolder else { continue }

      let enumerator = FileManager.default.enumerator(at: item.fileUrl,
                                                      includingPropertiesForKeys: [.isDirectoryKey],
                                                      options: [.skipsHiddenFiles], errorHandler: { (url, error) -> Bool in
        print("directoryEnumerator error at \(url): ", error)
        return true
      })!

      for case let fileURL as URL in enumerator {
        if !fileURL.isDirectoryFolder {
          item.subItems += 1
        } else if !self.watchers.contains(where: { $0.watchedUrl == fileURL }) {
          let watcher = DirectoryWatcher(watchedUrl: fileURL)
          self.watchers.append(watcher)

          watcher.onNewFiles = { [weak self] newFiles in
            guard let self = self else { return }
            item.subItems += newFiles.count
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
    return self.files.reduce(0) { result, item in
      return item.fileUrl.isDirectoryFolder
      ? result + item.subItems
      : result + 1
    }
  }

  public func deleteItem(_ item: URL) throws {
    try self.importManager.removeFile(item)
  }

  public func discardImportOperation() throws {
    try self.importManager.removeAllFiles()
  }

  public func createOperation() {
    self.importManager.createOperation()
    self.dismiss()
  }
}
