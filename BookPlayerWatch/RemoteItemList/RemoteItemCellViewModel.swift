//
//  RemoteItemCellViewModel.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 29/11/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerWatchKit
import Combine
import Foundation

class RemoteItemCellViewModel: ObservableObject {
  @Published var item: SimpleLibraryItem
  @Published var downloadState: DownloadState
  let coreServices: CoreServices

  private var disposeBag = Set<AnyCancellable>()

  init(item: SimpleLibraryItem, coreServices: CoreServices) {
    self.item = item
    self.coreServices = coreServices
    self._downloadState = .init(initialValue: coreServices.syncService.getDownloadState(for: item))
    bindObservers()
  }

  func bindObservers() {
    coreServices.syncService.downloadCompletedPublisher
      .filter({ [weak self] in
        $0.1 == self?.item.parentFolder || $0.2 == self?.item.parentFolder
      })
      .receive(on: DispatchQueue.main)
      .sink { [weak self] (relativePath, initiatingItemPath, _) in
        guard
          relativePath == self?.item.relativePath || initiatingItemPath == self?.item.relativePath
        else { return }

        self?.downloadState = .downloaded
      }.store(in: &disposeBag)

    coreServices.syncService.downloadProgressPublisher
      .filter({ [weak self] in
        $0.1 == self?.item.parentFolder || $0.2 == self?.item.parentFolder
      })
      .receive(on: DispatchQueue.main)
      .sink { [weak self] (relativePath, initiatingItemPath, _, progress) in
        guard
          relativePath == self?.item.relativePath || initiatingItemPath == self?.item.relativePath
        else { return }

        self?.downloadState = .downloading(progress: progress)
      }.store(in: &disposeBag)
  }

  func startDownload() async throws {
    let fileURL = item.fileURL
    /// Create backing folder if it does not exist
    if item.type == .folder || item.type == .bound {
      try DataManager.createBackingFolderIfNeeded(fileURL)
    }

    try await coreServices.syncService.downloadRemoteFiles(for: item)
  }

  func cancelDownload() throws {
    try coreServices.syncService.cancelDownload(of: item)
    downloadState = .notDownloaded
  }

  func offloadItem() throws {
    let fileURL = item.fileURL
    try FileManager.default.removeItem(at: fileURL)
    if item.type == .bound || item.type == .folder {
      try FileManager.default.createDirectory(
        at: fileURL,
        withIntermediateDirectories: false,
        attributes: nil
      )
    }
    downloadState = .notDownloaded
  }
}
