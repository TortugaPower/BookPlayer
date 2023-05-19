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
import Combine

/// Empty class meant to be subclassed to adjust service for test conditions
class EmptyLibraryServiceMock: LibraryServiceProtocol {
  var metadataUpdatePublisher: AnyPublisher<[String: Any], Never> = PassthroughSubject<[String: Any], Never>()
    .eraseToAnyPublisher()

  func getLibraryLastItem() -> BookPlayerKit.SimpleLibraryItem? {
    return nil
  }

  func getLibraryCurrentTheme() -> BookPlayerKit.SimpleTheme? {
    return nil
  }

  func setLibraryTheme(with simpleTheme: BookPlayerKit.SimpleTheme) { }

  func getLastPlayedItems(limit: Int?) -> [BookPlayerKit.SimpleLibraryItem]? {
    return nil
  }

  func getSimpleItem(with relativePath: String) -> BookPlayerKit.SimpleLibraryItem? {
    return nil
  }

  func findFirstItem(in parentFolder: String?, isUnfinished: Bool?) -> BookPlayerKit.SimpleLibraryItem? {
    return nil
  }

  func findFirstItem(in parentFolder: String?, beforeRank: Int16?) -> BookPlayerKit.SimpleLibraryItem? {
    return nil
  }

  func findFirstItem(in parentFolder: String?, afterRank: Int16?, isUnfinished: Bool?) -> BookPlayerKit.SimpleLibraryItem? {
    return nil
  }

  func getLibraryReference() -> BookPlayerKit.Library {
    return Library()
  }

  func getItemReference(with relativePath: String) -> BookPlayerKit.LibraryItem? {
    return nil
  }

  func getItems(notIn relativePaths: [String], parentFolder: String?) -> [BookPlayerKit.SimpleLibraryItem]? {
    return nil
  }

  func insertItems(from files: [URL]) -> [SimpleLibraryItem] {
    return []
  }

  func moveItems(_ items: [String], inside relativePath: String?) throws { }

  func delete(_ items: [BookPlayerKit.SimpleLibraryItem], mode: BookPlayerKit.DeleteMode) throws { }

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

  func getTheme(with title: String) -> Theme? {
    return nil
  }

  func setLibraryLastBook(with relativePath: String?) {}

  func createTheme(params: [String: Any]) -> SimpleTheme {
    return SimpleTheme(with: Theme())
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
      speed: 1,
      currentTime: 0,
      duration: 0,
      percentCompleted: 0,
      isFinished: false,
      relativePath: "",
      remoteURL: nil,
      artworkURL: nil,
      orderRank: 0,
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

  func reorderItem(
    with relativePath: String,
    inside folderRelativePath: String?,
    sourceIndexPath: IndexPath,
    destinationIndexPath: IndexPath
  ) {}

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

  func getBookmarks(of type: BookmarkType, relativePath: String) -> [SimpleBookmark]? {
    return nil
  }

  func getBookmark(at time: Double, relativePath: String, type: BookmarkType) -> SimpleBookmark? {
    return nil
  }

  func createBookmark(at time: Double, relativePath: String, type: BookmarkType) -> SimpleBookmark? {
    return nil
  }

  func addNote(_ note: String, bookmark: SimpleBookmark) {}

  func deleteBookmark(_ bookmark: SimpleBookmark) {}

  func renameItem(at relativePath: String, with newTitle: String) {}

  func insertItems(from files: [URL], into folder: Folder?, library: Library, processedItems: [LibraryItem]?) -> [LibraryItem] {
    return []
  }

  func handleDirectory(item: URL, folder: Folder, library: Library) {}

  func moveItems(_ items: [LibraryItem], inside relativePath: String?, moveFiles: Bool) throws {}

  func delete(_ items: [LibraryItem], mode: DeleteMode) throws {}

  func getItemProperty(_ property: String, relativePath: String) -> Any? {
    return nil
  }
}
