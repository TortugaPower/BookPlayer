//
//  StorageItem.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 21/8/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import Foundation

struct StorageItem: Identifiable {
  let id = UUID().uuidString
  let title: String
  let fileURL: URL
  let path: String
  let size: Int64
  let showWarning: Bool

  var formattedSize: String {
    ByteCountFormatter.string(fromByteCount: size, countStyle: ByteCountFormatter.CountStyle.file)
  }
}
