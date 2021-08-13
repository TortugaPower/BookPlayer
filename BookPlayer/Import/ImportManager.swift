//
//  ImportManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/10/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

/**
 Handles the creation of ImportOperation objects.
 It waits a specified time wherein new files may be added before the operation is created
 */
final class ImportManager {
  static let shared = ImportManager()

  private let timeout = 2.0
  private var subscription: AnyCancellable?
  private var timer: Timer?
  private var files = CurrentValueSubject<[URL], Never>([])

  public func process(_ fileUrl: URL) {
    // Avoid duplicating files
    guard !self.files.value.contains(where: { $0 == fileUrl }) else { return }

    // Avoid processing the creation of the Processed and Inbox folder
    if fileUrl.lastPathComponent == DataManager.processedFolderName
        || fileUrl.lastPathComponent == "Inbox" { return }

    self.files.value.append(fileUrl)
  }

  public func observeFiles() -> AnyPublisher<[URL], Never> {
    return self.files.eraseToAnyPublisher()
  }

  public func removeFile(_ item: URL, updateCollection: Bool = true) throws {
    try FileManager.default.removeItem(at: item)

    if updateCollection {
      self.files.value = self.files.value.filter { $0 != item }
    }
  }

  public func removeAllFiles() throws {
    for file in self.files.value {
      try self.removeFile(file, updateCollection: false)
    }

    self.files.value = []
  }

  public func createOperation() {
    guard !self.files.value.isEmpty else { return }

    let sortDescriptor = NSSortDescriptor(key: "path", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))
    let orderedSet = NSOrderedSet(array: self.files.value)

    guard let sortedFiles = orderedSet.sortedArray(using: [sortDescriptor]) as? [URL] else { return }

    let operation = ImportOperation(files: sortedFiles)

    self.files.value = []

    NotificationCenter.default.post(name: .importOperation, object: nil, userInfo: ["operation": operation])
  }
}
