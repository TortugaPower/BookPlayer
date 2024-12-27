//
//  BPLogger.swift
//  BookPlayer
//
//  Created by gianni.carlo on 10/7/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import Foundation
import os

public protocol BPLogger {}

extension BPLogger {
  public static var logger: Logger {
    return Logger(
      subsystem: Bundle.main.configurationString(for: .bundleIdentifier),
      category: String(describing: Self.self)
    )
  }

  /// This is only used for debug purposes in Betas, do not use in Prod build
  public static func logFile(message: String) {
    let debugLogFileURL = DataManager.getProcessedFolderURL().appendingPathComponent("debug_log_file.txt")

    do {
      try message.appendLineToURL(fileURL: debugLogFileURL)
    } catch {
      logger.debug("Could not write to log file")
    }
  }
}

/// Helper extensions to write to debug file
private extension Data {
  func append(fileURL: URL) throws {
    if let fileHandle = FileHandle(forWritingAtPath: fileURL.path) {
      defer {
        fileHandle.closeFile()
      }
      fileHandle.seekToEndOfFile()
      fileHandle.write(self)
    } else {
      try write(to: fileURL, options: .atomic)
    }
  }
}

private extension String {
  func appendLineToURL(fileURL: URL) throws {
    try (">>> " + self + "\n").appendToURL(fileURL: fileURL)
  }

  func appendToURL(fileURL: URL) throws {
    let data = self.data(using: String.Encoding.utf8)!
    try data.append(fileURL: fileURL)
  }
}
