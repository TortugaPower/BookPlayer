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

extension SimpleHardcoverBook {
  /// Metadata repair for a status-only stub (created when a synced-down Hardcover link
  /// crosses the reading threshold before this device ever fetched the book): metadata
  /// comes from the FETCHED copy, monotonic state (status, userBookID) stays LOCAL — a
  /// metadata repair must never regress reading progress already pushed to Hardcover,
  /// and losing userBookID would break the unlink flow's removal call.
  public func repairingMetadata(from fetched: SimpleHardcoverBook) -> SimpleHardcoverBook {
    SimpleHardcoverBook(
      id: fetched.id,
      artworkURL: fetched.artworkURL,
      title: fetched.title,
      author: fetched.author,
      status: status,
      userBookID: userBookID
    )
  }
}
