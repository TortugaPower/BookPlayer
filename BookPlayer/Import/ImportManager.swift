//
//  ImportManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/10/18.
//  Copyright © 2018 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

/**
 Handles the creation of ImportOperation objects.
 It waits a specified time wherein new files may be added before the operation is created
 */

final class ImportManager: ObservableObject {
  let queue = OperationQueue()
  private let libraryService: LibraryServiceProtocol
  private let timeout = 2.0
  private var subscription: AnyCancellable?
  private var timer: Timer?
  private var files = CurrentValueSubject<Set<URL>, Never>(Set())

  public var operationPublisher = PassthroughSubject<ImportOperation, Never>()

  init(libraryService: LibraryServiceProtocol) {
    self.libraryService = libraryService
  }

  public func process(_ fileUrl: URL) {
    // Avoid processing the creation of the Processed, Inbox and Backup folder
    if fileUrl.lastPathComponent == DataManager.processedFolderName
        || fileUrl.lastPathComponent == DataManager.inboxFolderName
        || fileUrl.lastPathComponent == DataManager.backupFolderName { return }

    self.files.value.insert(fileUrl)
  }

  public func hasPendingFiles() -> Bool {
    return !self.files.value.isEmpty
  }

  public func observeFiles() -> AnyPublisher<[URL], Never> {
    return self.files
      .map({ Array($0) })
      .eraseToAnyPublisher()
  }

  public func removeFile(_ item: URL, updateCollection: Bool = true) throws {
    if FileManager.default.fileExists(atPath: item.path),
       FileManager.default.isDeletableFile(atPath: item.path) {
      try FileManager.default.removeItem(at: item)
    }

    if updateCollection {
      self.files.value = self.files.value.filter { $0 != item }
    }
  }

  public func removeAllFiles() throws {
    let loadedFiles = self.files.value
    self.files.value = []

    for file in loadedFiles {
      try self.removeFile(file, updateCollection: false)
    }
  }

  public func createOperation() {
    guard !self.files.value.isEmpty else { return }

    let sortDescriptor = NSSortDescriptor(key: "path", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))
    let orderedSet = NSOrderedSet(set: self.files.value)
    // swiftlint:disable force_cast
    let sortedFiles = orderedSet.sortedArray(using: [sortDescriptor]) as! [URL]
    // swiftlint:enable force_cast

    let operation = ImportOperation(files: sortedFiles,
                                    libraryService: self.libraryService)

    self.files.value = []

    self.operationPublisher.send(operation)
  }

  public func start(_ operation: Operation) {
    self.queue.addOperation(operation)
  }

  @MainActor
  public func notifyPendingFiles() {
    // Get reference of all the files located inside the Documents, Shared and Inbox folders
    let documentsURLs =
      ((try? FileManager.default.contentsOfDirectory(
        at: DataManager.getDocumentsFolderURL(),
        includingPropertiesForKeys: nil,
        options: .skipsSubdirectoryDescendants
      )) ?? [])
      .filter {
        $0.lastPathComponent != DataManager.processedFolderName
          && $0.lastPathComponent != DataManager.inboxFolderName
          && $0.lastPathComponent != DataManager.backupFolderName
          && $0.lastPathComponent != DataManager.trashFolderName
      }

    let sharedURLs =
      (try? FileManager.default.contentsOfDirectory(
        at: DataManager.getSharedFilesFolderURL(),
        includingPropertiesForKeys: nil,
        options: .skipsSubdirectoryDescendants
      )) ?? []

    let inboxURLs =
      (try? FileManager.default.contentsOfDirectory(
        at: DataManager.getInboxFolderURL(),
        includingPropertiesForKeys: nil,
        options: .skipsSubdirectoryDescendants
      )) ?? []

    let urls = documentsURLs + sharedURLs + inboxURLs

    guard !urls.isEmpty else { return }

    processFiles(urls: urls)
  }

  func processFiles(urls: [URL]) {
    let temporaryDirectoryPath = FileManager.default.temporaryDirectory.absoluteString
    let documentsFolder = DataManager.getDocumentsFolderURL()

    for url in urls {
      /// At some point (iOS 17?), the OS stopped sending the picked files to the Documents/Inbox folder, instead
      /// it's now sent to a temp folder that can't be relied on to keep the file existing until the import is finished
      if url.absoluteString.contains(temporaryDirectoryPath) {
        let destinationURL = documentsFolder.appendingPathComponent(url.lastPathComponent)
        if !FileManager.default.fileExists(atPath: destinationURL.path) {
          try! FileManager.default.copyItem(at: url, to: destinationURL)
        }
      } else {
        process(url)
      }
    }
  }
}
