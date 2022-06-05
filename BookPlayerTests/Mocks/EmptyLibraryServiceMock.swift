//
//  EmptyLibraryServiceMock.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 18/5/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation

/// Empty class meant to be subclassed to adjust service for test conditions
class EmptyLibraryServiceMock: LibraryServiceProtocol {
  func addBook(from item: SyncedItem, parentFolder: String?) {}

  func addFolder(from item: SyncedItem, type: ItemType, parentFolder: String?) {}

  func getItemIdentifiers(notIn relativePaths: [String], parentFolder: String?) throws -> [String] { return [] }

  func updatePlaybackTime(relativePath: String, time: Double, date: Date) {}

  func getLibrary() -> Library {
    return Library()
  }

  func getLibraryLastItem() throws -> LibraryItem? {
    return nil
  }

  func getLibraryCurrentTheme() throws -> Theme? {
    return nil
  }

  func getTheme(with title: String) -> Theme? {
    return nil
  }

  func setLibraryTheme(with title: String) {}

  func setLibraryLastBook(with relativePath: String?) {}

  func createTheme(params: [String: Any]) -> Theme {
    return Theme()
  }

  func createBook(from url: URL) -> Book {
    return Book()
  }

  func getChapters(from relativePath: String) -> [Chapter]? {
    return nil
  }

  func getItem(with relativePath: String) -> LibraryItem? {
    return nil
  }

  func findBooks(containing fileURL: URL) -> [Book]? {
    return nil
  }

  func getLastPlayedItems(limit: Int?) -> [LibraryItem]? {
    return nil
  }

  func updateFolder(at relativePath: String, type: ItemType) throws {}

  func findFolder(with fileURL: URL) -> Folder? {
    return nil
  }

  func findFolder(with relativePath: String) -> Folder? {
    return nil
  }

  func hasLibraryLinked(item: LibraryItem) -> Bool {
    return false
  }

  func createFolder(with title: String, inside relativePath: String?) throws -> Folder {
    return Folder()
  }

  func fetchContents(at relativePath: String?, limit: Int?, offset: Int?) -> [LibraryItem]? {
    return nil
  }

  func getMaxItemsCount(at relativePath: String?) -> Int {
    return 0
  }

  func replaceOrderedItems(_ items: NSOrderedSet, at relativePath: String?) {}

  func reorderItem(at relativePath: String, inside folderRelativePath: String?, sourceIndexPath: IndexPath, destinationIndexPath: IndexPath) {}

  func updatePlaybackTime(relativePath: String, time: Double) {}

  func updateBookSpeed(at relativePath: String, speed: Float) {}

  func getItemSpeed(at relativePath: String) -> Float {
    return 1
  }

  func updateBookLastPlayDate(at relativePath: String, date: Date) {}

  func markAsFinished(flag: Bool, relativePath: String) {}

  func jumpToStart(relativePath: String) {}

  func getCurrentPlaybackRecord() -> PlaybackRecord {
    return PlaybackRecord()
  }

  func getPlaybackRecords(from startDate: Date, to endDate: Date) -> [PlaybackRecord]? {
    return nil
  }

  func recordTime(_ playbackRecord: PlaybackRecord) {}

  func getBookmarks(of type: BookmarkType, relativePath: String) -> [Bookmark]? {
    return nil
  }

  func getBookmark(at time: Double, relativePath: String, type: BookmarkType) -> Bookmark? {
    return nil
  }

  func createBookmark(at time: Double, relativePath: String, type: BookmarkType) -> Bookmark {
    return Bookmark()
  }

  func addNote(_ note: String, bookmark: Bookmark) {}

  func deleteBookmark(_ bookmark: Bookmark) {}

  func renameItem(at relativePath: String, with newTitle: String) {}

  func insertItems(from files: [URL], into folder: Folder?, library: Library, processedItems: [LibraryItem]?) -> [LibraryItem] {
    return []
  }

  func handleDirectory(item: URL, folder: Folder, library: Library) {}

  func moveItems(_ items: [LibraryItem], inside relativePath: String?, moveFiles: Bool) throws {}

  func delete(_ items: [LibraryItem], mode: DeleteMode) throws {}
}
