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
  /// The import screen is up, from when it starts appearing until it has disappeared, however it
  /// closes (set by the screen). The library's placement prompt waits for it: a presentation
  /// started under it is dropped.
  @Published var isImportScreenShown = false

  init(libraryService: LibraryServiceProtocol) {
    self.libraryService = libraryService
  }

  public func process(_ fileUrl: URL) {
    // Avoid processing the creation of the Processed, Inbox and Backup folder
    if fileUrl.lastPathComponent == DataManager.processedFolderName
        || fileUrl.lastPathComponent == DataManager.inboxFolderName
        || fileUrl.lastPathComponent == DataManager.backupFolderName {
      return
    }

    // One file can arrive under two spellings: the folder watchers and `notifyPendingFiles` give
    // `/var/…`, a file of ours opened from the Files app gives `/private/var/…`. Queued twice, the
    // import moved it on the first copy and crashed on the second.
    let fileUrl = fileUrl.resolvingSymlinksInPath()

    // A file that's gone or can't be read never reaches the import screen
    guard Self.isImportable(fileUrl) else { return }

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

  /// Checked once when a file is queued and once more when the import takes it, never on every
  /// change: a batch of a thousand files would check every file again for each one queued.
  private static func isImportable(_ url: URL) -> Bool {
    FileManager.default.isReadableFile(atPath: url.path)
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

  /// The import of the pending files, which it takes: files arriving afterwards wait for the next
  /// import, and discarding the pending files no longer touches these. Start it by sending it on
  /// `operationPublisher`, once the import screen has closed: the library's placement prompt
  /// relies on every import being confirmed there.
  public func prepareOperation() -> ImportOperation? {
    // A file gone since it was listed is left out
    let importableFiles = self.files.value.filter(Self.isImportable)
    self.files.value = []

    guard !importableFiles.isEmpty else {
      return nil
    }

    let sortDescriptor = NSSortDescriptor(key: "path", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))
    let orderedSet = NSOrderedSet(set: importableFiles)
    // swiftlint:disable force_cast
    let sortedFiles = orderedSet.sortedArray(using: [sortDescriptor]) as! [URL]
    // swiftlint:enable force_cast

    return ImportOperation(files: sortedFiles,
                           libraryService: self.libraryService)
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

    guard !urls.isEmpty else {
      return
    }

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
          destinationURL.disableFileProtection()
        }
      } else {
        process(url)
      }
    }
  }
}
