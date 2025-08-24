//
//  DownloadState.swift
//  BookPlayer
//
//  Created by gianni.carlo on 19/2/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import Foundation

public enum DownloadState: Hashable {
  /// The asset is not downloaded.
  case notDownloaded
  /// The asset has a download in progress.
  case downloading(progress: Double)
  /// The asset is downloaded and saved on disk.
  case downloaded
}
