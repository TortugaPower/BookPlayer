//
//  BookmarksService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 6/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import CoreData
import Foundation

class BookmarksService {
  public class func getBookmark(at time: Double, book: Book, type: BookmarkType) -> Bookmark? {
    let time = floor(time)

    let fetchRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "%K == %@ && type == %d && time == %f", #keyPath(Bookmark.book.relativePath), book.relativePath, type.rawValue, floor(time))

    return try? DataManager.getContext().fetch(fetchRequest).first
  }

  public class func createBookmark(at time: Double, book: Book, type: BookmarkType) -> Bookmark {
    return DataManager.createBookmark(at: time, book: book, type: type)
  }

  public class func createOrUpdateBookmark(at time: Double, book: Book, type: BookmarkType) {
    let bookmark = DataManager.getBookmark(of: type, for: book)
      ?? DataManager.createBookmark(at: time, book: book, type: type)
    bookmark.time = floor(time)
    bookmark.note = type.getNote()
    DataManager.saveContext()
  }

  public class func updateNote(_ note: String, for bookmark: Bookmark) {
    DataManager.addNote(note, bookmark: bookmark)
  }
}
