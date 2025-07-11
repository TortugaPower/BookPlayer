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
import ZipArchive

/// Reference: https://www.avanderlee.com/swift/asynchronous-operations/
public class ImportOperation: Operation {
  public let files: [URL]
  public let libraryService: LibraryServiceProtocol
  public var processedFiles = [URL]()
  public var suggestedFolderName: String?

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
       libraryService: LibraryServiceProtocol) {
    self.files = files
    self.libraryService = libraryService
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

  func handleZip(file: URL, remainingFiles: [URL]) {
    self.suggestedFolderName = file.deletingPathExtension().lastPathComponent

    // Unzip to temporary directory
    let documentsURL = DataManager.getDocumentsFolderURL()

    let tempDirectoryURL = try! FileManager.default.url(
      for: .itemReplacementDirectory,
      in: .userDomainMask,
      appropriateFor: documentsURL,
      create: true
    )

    SSZipArchive.unzipFile(atPath: file.path, toDestination: tempDirectoryURL.path, progressHandler: nil) { _, success, error in
      try? FileManager.default.removeItem(at: file)

      guard success else {
        self.processFile(from: remainingFiles)
        return
      }

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

      self.processFile(from: remainingFiles + files)
    }
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
      newFileName = "\(filename)-\(counter)"

      if !fileExt.isEmpty {
        newFileName += ".\(fileExt)"
      }

      mutableURL = destinationBaseURL.appendingPathComponent(newFileName)
    }

    return mutableURL
  }

  private func hasExistingBook(_ fileURL: URL) -> Bool {
    guard
      let existingBook = self.libraryService.findBooks(containing: fileURL)?.first,
      let existingFileURL = existingBook.fileURL,
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

      if accessGranted {
        try FileManager.default.copyItem(at: fileURL, to: existingFileURL)
      } else {
        try FileManager.default.moveItem(at: fileURL, to: existingFileURL)
      }

      existingFileURL.disableFileProtection()
    } catch {
      fatalError("Existing book, fail to move file from \(fileURL) to \(existingFileURL). Error: \(error.localizedDescription)")
    }

    return true
  }

  public override func main() {
    self.detectFolderOrganization()
    self.processFile(from: self.files)
  }

  private func detectFolderOrganization() {
    guard files.count > 1 else { return }

    let documentsURL = DataManager.getDocumentsFolderURL()
    var parentFolders = Set<String>()

    for file in files {
        let parentURL = file.deletingLastPathComponent()

        guard parentURL != documentsURL else { continue }

        parentFolders.insert(parentURL.lastPathComponent)
    }

    guard parentFolders.count == 1, let folderName = parentFolders.first else { return }
    suggestedFolderName = folderName
  }

  func processFile(from files: [URL]) {
    var mutableFiles = files
    guard !mutableFiles.isEmpty else {
      return self.finish()
    }

    let currentFile = mutableFiles.removeFirst()

    guard !self.hasExistingBook(currentFile) else {
      return processFile(from: mutableFiles)
    }

    NotificationCenter.default.post(name: .processingFile, object: nil, userInfo: ["filename": currentFile.lastPathComponent])

    if shouldUnzip(currentFile) {
      self.handleZip(file: currentFile, remainingFiles: mutableFiles)
      return
    }

    // Add support for iCloud documents
    let accessGranted = currentFile.startAccessingSecurityScopedResource()

    defer { currentFile.stopAccessingSecurityScopedResource() }

    let destinationURL = self.getNextAvailableURL(for: currentFile)

    do {
      if accessGranted {
        try FileManager.default.copyItem(at: currentFile, to: destinationURL)
      } else {
        try FileManager.default.moveItem(at: currentFile, to: destinationURL)
      }

      destinationURL.disableFileProtection()
    } catch {
      fatalError("Fail to move file from \(currentFile) to \(destinationURL). Error: \(error.localizedDescription)")
    }

    self.processedFiles.append(destinationURL)
    self.processFile(from: mutableFiles)
  }
  
  func shouldUnzip(_ file: URL) -> Bool {
    return file.pathExtension == "zip" || file.pathExtension == "lpf"
  }
}
