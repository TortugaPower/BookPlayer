//
//  StorageItem.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 21/8/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation

struct StorageItem {
  let title: String
  let fileURL: URL
  let path: String
  let size: Int64
  let showWarning: Bool

  func formattedSize() -> String {
    return ByteCountFormatter.string(fromByteCount: self.size, countStyle: ByteCountFormatter.CountStyle.file)
  }
}
