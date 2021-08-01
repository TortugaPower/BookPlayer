//
//  BookOperation.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 8/30/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation
import IDZSwiftCommonCrypto
import ZipArchive

/**
 Process files located at a specific `URL`, renames it with the hash and moves it to the specified destination folder.
 The new file maintains the extension of the original `URL`
 */

public class ImportOperation: Operation {
  public let files: [URL]
  public var processedFiles = [URL]()

    init(files: [URL]) {
        self.files = files
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

  func handleZip(file: URL) {
    guard file.pathExtension == "zip" else { return }

    // Unzip to documents directory
    SSZipArchive.unzipFile(atPath: file.path, toDestination: DataManager.getDocumentsFolderURL().path, progressHandler: nil) { _, success, error in
      defer {
        // Delete original zip file
        try? FileManager.default.removeItem(at: file)
      }

      guard success else {
        print("Extraction of ZIP archive failed with error:\(String(describing: error))")
        return
      }
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

  public override func main() {
    for file in self.files {
      NotificationCenter.default.post(name: .processingFile, object: nil, userInfo: ["filename": file.lastPathComponent])

      guard file.pathExtension != "zip" else {
        self.handleZip(file: file)
        continue
      }

      let destinationURL = self.getNextAvailableURL(for: file)

      do {
        try FileManager.default.moveItem(at: file, to: destinationURL)
        try (destinationURL as NSURL).setResourceValue(URLFileProtection.none, forKey: .fileProtectionKey)
      } catch {
        fatalError("Fail to move file from \(file) to \(destinationURL)")
      }

      self.processedFiles.append(destinationURL)
    }
  }
}
