//
//  SimpleHardcoverItem.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/28/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

public struct SimpleHardcoverBook {
  public let id: Int
  public let artworkURL: URL?
  public let title: String
  public let author: String
  public var status: HardcoverBook.Status
  public var userBookID: Int?

  public init(
    id: Int,
    artworkURL: URL?,
    title: String,
    author: String,
    status: HardcoverBook.Status,
    userBookID: Int? = nil
  ) {
    self.id = id
    self.artworkURL = artworkURL
    self.title = title
    self.author = author
    self.status = status
    self.userBookID = userBookID
  }
}
