//
//  DataManager+WatchApp.swift
//  BookPlayerWatch Extension
//
//  Created by Gianni Carlo on 4/27/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import BookPlayerWatchKit

extension DataManager {
  public static let libraryDataUrl = FileManager.default
    .urls(for: .documentDirectory, in: .userDomainMask).first!
    .appendingPathComponent("library.data")

  public static let themeDataUrl = FileManager.default
    .urls(for: .documentDirectory, in: .userDomainMask).first!
    .appendingPathComponent("library.theme.data")

  public static let booksDataUrl = FileManager.default
    .urls(for: .documentDirectory, in: .userDomainMask).first!
    .appendingPathComponent("library.books.data")

  public func loadLibraryData() -> WatchDataObject? {
    return self.decodeLibraryData(booksData: FileManager.default.contents(atPath: DataManager.booksDataUrl.path),
                                  themeData: FileManager.default.contents(atPath: DataManager.themeDataUrl.path))
  }

  public func decodeLibraryData(booksData: Data?, themeData: Data?) -> WatchDataObject? {
    guard let booksData = booksData else { return nil }

    try? booksData.write(to: DataManager.booksDataUrl)
    try? themeData?.write(to: DataManager.themeDataUrl)

    let bgContext = self.getBackgroundContext()
    let decoder = JSONDecoder()

    guard let context = CodingUserInfoKey.context else { return nil }

    decoder.userInfo[context] = bgContext

    guard let books = try? decoder.decode([Book].self, from: booksData) else {
      return nil
    }

    var currentTheme: Theme?
    if let themeData = themeData {
      currentTheme = try? decoder.decode(Theme.self, from: themeData)
    }

    return (books: books, currentTheme: currentTheme)
  }
}
