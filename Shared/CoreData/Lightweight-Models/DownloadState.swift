//
//  DownloadState.swift
//  BookPlayer
//
//  Created by gianni.carlo on 19/2/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation

public enum DownloadState: Hashable {
  /// The asset is not downloaded.
  case notDownloaded
  /// The asset has a download in progress.
  case downloading(progress: Double)
  /// The asset is downloaded and saved on disk.
  case downloaded

  public func hash(into hasher: inout Hasher) {
    // Custom implementation of hashable protocol to ignore the
    // associated values when computing a hash value
    switch self {
    case .notDownloaded:
      hasher.combine(0)
    case .downloading:
      hasher.combine(1)
    case .downloaded:
      hasher.combine(2)
    }
  }

  public static func == (lhs: DownloadState, rhs: DownloadState) -> Bool {
    // Custom implementation of Equatable protocol to ignore the
    // associated values when comparing values
    switch (lhs, rhs) {
    case (.notDownloaded, .notDownloaded): return true
    case (.downloading, .downloading): return true
    case (.downloaded, .downloaded): return true
    default: return false
    }
  }
}
