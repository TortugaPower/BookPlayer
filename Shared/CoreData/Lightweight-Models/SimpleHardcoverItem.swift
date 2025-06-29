//
//  SimpleHardcoverItem.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/28/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

public struct SimpleHardcoverItem {
  public let id: Int
  public let artworkURL: URL?
  public let title: String
  public let author: String
  public let status: HardcoverItem.Status

  public init(
    id: Int,
    artworkURL: URL?,
    title: String,
    author: String,
    status: HardcoverItem.Status
  ) {
    self.id = id
    self.artworkURL = artworkURL
    self.title = title
    self.author = author
    self.status = status
  }
}
