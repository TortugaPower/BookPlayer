//
//  LibraryService+FetchRequests.swift
//  BookPlayer
//
//  Created by gianni.carlo on 24/6/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation
import CoreData

extension LibraryService {
  static func bookmarkReferenceFetchRequest(bookmark: SimpleBookmark) -> NSFetchRequest<Bookmark> {
    let fetchRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
    fetchRequest.predicate = NSPredicate(
      format: "%K == %@ && type == %d && time == %f",
      #keyPath(Bookmark.item.relativePath),
      bookmark.relativePath,
      bookmark.type.rawValue,
      bookmark.time
    )
    fetchRequest.fetchLimit = 1
    fetchRequest.propertiesToFetch = [
      #keyPath(Bookmark.time),
      #keyPath(Bookmark.note),
      #keyPath(Bookmark.type),
    ]

    return fetchRequest
  }

  static func simpleBookmarkFetchRequest(
    time: Double?,
    relativePath: String,
    type: BookmarkType
  ) -> NSFetchRequest<NSDictionary> {
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "Bookmark")
    fetchRequest.propertiesToFetch = SimpleBookmark.fetchRequestProperties
    fetchRequest.resultType = .dictionaryResultType
    if let time {
      fetchRequest.predicate = NSPredicate(
        format: "%K == %@ && type == %d && time == %f",
        #keyPath(Bookmark.item.relativePath),
        relativePath,
        type.rawValue,
        floor(time)
      )
    } else {
      fetchRequest.predicate = NSPredicate(
        format: "%K == %@ && type == %d",
        #keyPath(Bookmark.item.relativePath),
        relativePath,
        type.rawValue
      )
    }
    let sort = NSSortDescriptor(key: #keyPath(Bookmark.time), ascending: true)
    fetchRequest.sortDescriptors = [sort]

    return fetchRequest
  }

  static func itemReferenceFetchRequest(relativePath: String) -> NSFetchRequest<LibraryItem> {
    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.relativePath), relativePath)
    fetchRequest.fetchLimit = 1
    fetchRequest.propertiesToFetch = [
      #keyPath(LibraryItem.relativePath),
      #keyPath(LibraryItem.originalFileName)
    ]

    return fetchRequest
  }
}
