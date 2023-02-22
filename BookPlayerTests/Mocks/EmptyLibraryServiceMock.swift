//
//  EmptyLibraryServiceMock.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 18/5/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import AVFoundation
import BookPlayerKit
import Foundation

/// Empty class meant to be subclassed to adjust service for test conditions
class EmptyLibraryServiceMock: LibraryServiceProtocol {
  func loadChaptersIfNeeded(relativePath: String, asset: AVAsset) { }

  func getTotalListenedTime() -> TimeInterval { return 0 }

  func renameItem(at relativePath: String, with newTitle: String) throws -> String { return "" }

  func updateDetails(at relativePath: String, details: String) {}

  func filterContents(
    at relativePath: String?,
    query: String?,
    scope: SimpleItemType,
    limit: Int?,
    offset: Int?
  ) -> [SimpleLibraryItem]? {
    return []
  }

  func rebuildFolderDetails(_ relativePath: String) {}

  func recursiveFolderProgressUpdate(from relativePath: String) {}

  func addBook(from item: SyncableItem, parentFolder: String?) {}

  func addFolder(from item: SyncableItem, type: ItemType, parentFolder: String?) {}

  func getItems(notIn relativePaths: [String], parentFolder: String?) throws -> [String] { return [] }

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

  func getChapters(from relativePath: String) -> [SimpleChapter]? {
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

  func updateFolder(at relativePath: String, type: SimpleItemType) throws {}

  func findFolder(with fileURL: URL) -> Folder? {
    return nil
  }

  func findFolder(with relativePath: String) -> Folder? {
    return nil
  }

  func hasLibraryLinked(item: LibraryItem) -> Bool {
    return false
  }

  func createFolder(with title: String, inside relativePath: String?) throws -> SimpleLibraryItem {
    return SimpleLibraryItem(
      title: "",
      details: "",
      duration: 0,
      percentCompleted: 0,
      isFinished: false,
      relativePath: "",
      parentFolder: nil,
      originalFileName: "",
      lastPlayDate: nil,
      type: .folder
    )
  }

  func fetchContents(at relativePath: String?, limit: Int?, offset: Int?) -> [SimpleLibraryItem]? {
    return nil
  }

  func getMaxItemsCount(at relativePath: String?) -> Int {
    return 0
  }

  func sortContents(at relativePath: String?, by type: SortType) {}

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

  func createBookmark(at time: Double, relativePath: String, type: BookmarkType) -> Bookmark? {
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

  func findFirstItem(in parentFolder: String?, isUnfinished: Bool?) -> LibraryItem? {
    return nil
  }

  func findFirstItem(in parentFolder: String?, beforeRank: Int16?) -> LibraryItem? {
    return nil
  }

  func findFirstItem(in parentFolder: String?, afterRank: Int16?, isUnfinished: Bool?) -> LibraryItem? {
    return nil
  }

  func getItemProperty(_ property: String, relativePath: String) -> Any? {
    return nil
  }
}
