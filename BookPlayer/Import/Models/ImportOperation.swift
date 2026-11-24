//
//  BookOperation.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 8/30/18.
//  Copyright © 2018 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation
import IDZSwiftCommonCrypto
import Sentry
import ZipArchive

/// Reference: https://www.avanderlee.com/swift/asynchronous-operations/
public class ImportOperation: Operation {
  public let files: [URL]
  public let libraryService: LibraryServiceProtocol
  public var processedFiles = [URL]()
  public var suggestedFolderName: String?
  /// A folder the files come from that this import owns, like the Transfer from Computer flow's
  /// holding folder: it never suggests a folder name, and it's removed when the import finishes.
  private let ownedSourceRoot: URL?

  private let lockQueue = DispatchQueue(label: "com.bookplayer.asyncoperation", attributes: .concurrent)

  public override var isAsynchronous: Bool {
    return true
  }

  private var _isExecuting: Bool = false
  public override private(set) var isExecuting: Bool {
    get {
      return lockQueue.sync { () -> Bool in
        return _isExecuting
      }
    }
    set {
      willChangeValue(forKey: "isExecuting")
      lockQueue.sync(flags: [.barrier]) {
        _isExecuting = newValue
      }
      didChangeValue(forKey: "isExecuting")
    }
  }

  private var _isFinished: Bool = false
  public override private(set) var isFinished: Bool {
    get {
      return lockQueue.sync { () -> Bool in
        return _isFinished
      }
    }
    set {
      willChangeValue(forKey: "isFinished")
      lockQueue.sync(flags: [.barrier]) {
        _isFinished = newValue
      }
      didChangeValue(forKey: "isFinished")
    }
  }

  init(files: [URL],
       libraryService: LibraryServiceProtocol,
       ownedSourceRoot: URL? = nil) {
    self.files = files
    self.libraryService = libraryService
    self.ownedSourceRoot = ownedSourceRoot
  }

  public override func start() {
    guard !isCancelled else {
      finish()
      return
    }

    isFinished = false
    isExecuting = true
    main()
  }

  func finish() {
    let sortDescriptor = NSSortDescriptor(key: "path", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))
    let orderedSet = NSOrderedSet(array: self.processedFiles)

    if let sortedFiles = orderedSet.sortedArray(using: [sortDescriptor]) as? [URL] {
      self.processedFiles = sortedFiles
    }

    if let ownedSourceRoot {
      try? FileManager.default.removeItem(at: ownedSourceRoot)
    }

    isExecuting = false
    isFinished = true
  }

  func getInfo() -> [String: String] {
    var dictionary = [String: Int]()
    for file in self.files {
      dictionary[file.pathExtension] = (dictionary[file.pathExtension] ?? 0) + 1
    }
    var finalInfo = [String: String]()
    for (key, value) in dictionary {
      finalInfo[key] = "\(value)"
    }

    return finalInfo
  }

  /// Unpacks the archive into a temporary folder and removes it. Returns its top-level items, for the
  /// import to take next.
  func handleZip(file: URL) -> [URL] {
    self.suggestedFolderName = file.deletingPathExtension().lastPathComponent

    // Unzip to temporary directory
    let documentsURL = DataManager.getDocumentsFolderURL()

    let tempDirectoryURL = try! FileManager.default.url(
      for: .itemReplacementDirectory,
      in: .userDomainMask,
      appropriateFor: documentsURL,
      create: true
    )

    let success = SSZipArchive.unzipFile(atPath: file.path, toDestination: tempDirectoryURL.path)
    try? FileManager.default.removeItem(at: file)

    guard success else { return [] }

    let enumerator = FileManager.default.enumerator(
      at: tempDirectoryURL,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: { (url, error) -> Bool in
        print("directoryEnumerator error at \(url): ", error)
        return true
      })!

    var files = [URL]()
    for case let fileURL as URL in enumerator {
      files.append(fileURL)
    }

    return files
  }

  func getNextAvailableURL(for url: URL) -> URL {
    guard FileManager.default.fileExists(atPath: url.path)  else {
      return url
    }

    let destinationBaseURL = DataManager.getProcessedFolderURL()
    let filename = url.deletingPathExtension().lastPathComponent
    let fileExt = url.pathExtension

    // set initial state for new file name
    var newFileName = ""
    var counter = 0
    var mutableURL = destinationBaseURL.appendingPathComponent(url.lastPathComponent)

    while FileManager.default.fileExists(atPath: mutableURL.path) {
      counter += 1
      newFileName = Self.numberedFileName(stem: filename, counter: counter, fileExtension: fileExt)
      mutableURL = destinationBaseURL.appendingPathComponent(newFileName)
    }

    return mutableURL
  }

  /// `<stem>-<counter>.<extension>`, within the file system's 255-byte limit on a name. A stem too long
  /// for the suffix loses characters from its middle: its start, which sorting looks at, and its end,
  /// where track numbers usually are, both stay.
  static func numberedFileName(stem: String, counter: Int, fileExtension: String) -> String {
    let suffix = "-\(counter)" + (fileExtension.isEmpty ? "" : ".\(fileExtension)")
    let stemBudget = maxFileNameBytes - suffix.utf8.count
    guard stem.utf8.count > stemBudget else { return stem + suffix }

    var head = ""
    for character in stem {
      guard head.utf8.count + character.utf8.count <= stemBudget / 2 else { break }
      head.append(character)
    }

    var tail = ""
    for character in stem.reversed() {
      guard head.utf8.count + tail.utf8.count + character.utf8.count <= stemBudget else { break }
      tail.insert(character, at: tail.startIndex)
    }

    return head + tail + suffix
  }

  private static let maxFileNameBytes = 255

  private func hasExistingBook(_ fileURL: URL) -> Bool {
    guard
      let existingFileURL = self.libraryService.findBookFileURL(matching: fileURL),
      !FileManager.default.fileExists(atPath: existingFileURL.path)
    else { return false }

    // Add support for iCloud documents
    let accessGranted = fileURL.startAccessingSecurityScopedResource()

    defer { fileURL.stopAccessingSecurityScopedResource() }

    do {
      // create parent folder if it doesn't exist
      let parentFolder = existingFileURL.deletingLastPathComponent()

      if !FileManager.default.fileExists(atPath: parentFolder.path) {
        try FileManager.default.createDirectory(at: parentFolder, withIntermediateDirectories: true, attributes: nil)
      }

      try FileManager.default.copyItem(at: fileURL, to: existingFileURL)

      if DataManager.isAppManagedSource(fileURL) {
        fileURL.disableFileProtection()
        try? FileManager.default.removeItem(at: fileURL)
      }

      existingFileURL.disableFileProtection()
    } catch {
      SentrySDK.capture(error: error) { scope in
        scope.setContext(value: [
          "source": fileURL.path,
          "destination": existingFileURL.path,
          "securityScopedAccess": accessGranted
        ], key: "import")
      }
      SentrySDK.flush(timeout: 2)
      fatalError("Existing book, fail to move file from \(fileURL) to \(existingFileURL). Error: \(error.localizedDescription)")
    }

    return true
  }

  public override func main() {
    self.detectFolderOrganization()

    // One file at a time in a loop: going on to the next file from the last one's call overflowed
    // the operation thread's stack on batches of a few hundred files. An archive's items join the end.
    var queue = self.files
    var index = 0
    while index < queue.count {
      let file = queue[index]
      index += 1
      queue.append(contentsOf: autoreleasepool { self.processFile(file) })
    }

    self.finish()
  }

  private func detectFolderOrganization() {
    guard files.count > 1 else { return }

    var topLevelImportPaths: Set<String> = [
      DataManager.getDocumentsFolderURL().resolvingSymlinksInPath().path,
      DataManager.getSharedFilesFolderURL().resolvingSymlinksInPath().path,
      DataManager.getInboxFolderURL().resolvingSymlinksInPath().path,
    ]
    if let ownedSourceRoot {
      topLevelImportPaths.insert(ownedSourceRoot.resolvingSymlinksInPath().path)
    }
    var parentFolders = Set<String>()

    for file in files {
        let parentURL = file.deletingLastPathComponent()

        guard !topLevelImportPaths.contains(parentURL.resolvingSymlinksInPath().path) else { continue }

        parentFolders.insert(parentURL.lastPathComponent)
    }

    guard parentFolders.count == 1, let folderName = parentFolders.first else { return }
    suggestedFolderName = folderName
  }

  /// Imports one file. Returns the items it unpacked when it's an archive.
  func processFile(_ currentFile: URL) -> [URL] {
    guard !self.hasExistingBook(currentFile) else { return [] }

    NotificationCenter.default.post(name: .processingFile, object: nil, userInfo: ["filename": currentFile.lastPathComponent])

    if shouldUnzip(currentFile) {
      return self.handleZip(file: currentFile)
    }

    // Add support for iCloud documents
    let accessGranted = currentFile.startAccessingSecurityScopedResource()

    defer { currentFile.stopAccessingSecurityScopedResource() }

    let destinationURL = self.getNextAvailableURL(for: currentFile)

    do {
      try FileManager.default.copyItem(at: currentFile, to: destinationURL)

      if DataManager.isAppManagedSource(currentFile) {
        currentFile.disableFileProtection()
        try FileManager.default.removeItem(at: currentFile)
      }

      destinationURL.disableFileProtection()
    } catch {
      SentrySDK.capture(error: error) { scope in
        scope.setContext(value: [
          "source": currentFile.path,
          "destination": destinationURL.path,
          "securityScopedAccess": accessGranted
        ], key: "import")
      }
      SentrySDK.flush(timeout: 2)
      fatalError("Fail to move file from \(currentFile) to \(destinationURL). Error: \(error.localizedDescription)")
    }

    self.processedFiles.append(destinationURL)
    return []
  }

  func shouldUnzip(_ file: URL) -> Bool {
    return file.pathExtension == "zip" || file.pathExtension == "lpf"
  }
}
