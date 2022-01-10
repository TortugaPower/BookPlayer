//
//  CarPlayManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 8/12/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Kingfisher
import MediaPlayer
import Themeable
import UIKit

enum IndexGuide {
  case tab

  var recentlyPlayed: Int {
    return 1
  }

  case library
  case folder

  var count: Int {
    switch self {
    case .tab:
      return 1
    case .library:
      return 2
    case .folder:
      return 3
    }
  }

  var content: Int {
    switch self {
    case .tab:
      return 0
    case .library:
      return 1
    case .folder:
      return 2
    }
  }
}

final class CarPlayManager: NSObject, MPPlayableContentDataSource, MPPlayableContentDelegate {
  typealias Tab = (identifier: String, title: String, imageName: String)
  let tabs: [Tab] = [("tab-library", "library_title".localized, "books.vertical.fill"),
                     ("tab-recent", "recent_title".localized, "clock.fill")]
  var cachedDataStore = [IndexPath: [SimpleLibraryItem]]()
  let libraryService: LibraryServiceProtocol
  var themeAccent: UIColor
  private var disposeBag = Set<AnyCancellable>()
  public private(set) var defaultArtwork: UIImage

  init(libraryService: LibraryServiceProtocol) {
    self.libraryService = libraryService
    self.themeAccent = UIColor(hex: "3488D1")
    self.defaultArtwork = ArtworkService.generateDefaultArtwork(from: nil)!

    super.init()
    self.bindObservers()
    self.setUpTheming()
  }

  func bindObservers() {
    NotificationCenter.default.publisher(for: .bookPlayed)
      .sink { [weak self] notification in
        guard let self = self,
              let userInfo = notification.userInfo,
              let book = userInfo["book"] as? Book else {
                return
              }

        self.setNowPlayingInfo(with: book)
      }
      .store(in: &disposeBag)
  }

  func createTabItem(for indexPath: IndexPath) -> MPContentItem {
    let tab = self.tabs[indexPath[IndexGuide.tab.content]]
    let item = MPContentItem(identifier: tab.identifier)
    item.title = tab.title
    item.isContainer = true
    item.isPlayable = false
    if let tabImage = UIImage(systemName: tab.imageName) {
      item.artwork = MPMediaItemArtwork(boundsSize: tabImage.size, requestHandler: { _ -> UIImage in
        tabImage
      })
    }

    return item
  }

  func populateCachedData(at indexPath: IndexPath) -> Int {
    var mutableIndexPath = indexPath
    let sourceIndex = mutableIndexPath.removeFirst()

    let baseIndex = IndexPath(index: sourceIndex)

    guard let items = self.cachedDataStore[baseIndex]
            ?? self.getSourceItems(for: sourceIndex) else {
      return 0
    }

    if mutableIndexPath.isEmpty {
      self.cachedDataStore[indexPath] = items
      return items.count
    }

    let item = self.getItem(from: items, and: mutableIndexPath)

    if item.type == .folder,
       let folderItems = self.libraryService.fetchContents(at: item.relativePath, limit: nil, offset: nil) {
      let folderItems = folderItems.map({ SimpleLibraryItem(from: $0,
                                                            themeAccent: themeAccent) })
      self.cachedDataStore[indexPath] = folderItems
      return folderItems.count
    } else {
      return 0
    }
  }

  func numberOfChildItems(at indexPath: IndexPath) -> Int {
    if indexPath.indices.isEmpty {
      return 2
    }

    if let items = self.cachedDataStore[indexPath] {
      return items.count
    }

    return self.populateCachedData(at: indexPath)
  }

  func contentItem(at indexPath: IndexPath) -> MPContentItem? {
    // Populate tabs
    if indexPath.indices.count == IndexGuide.tab.count {
      return self.createTabItem(for: indexPath)
    }

    var mutableIndexPath = indexPath
    let index = mutableIndexPath.removeLast()

    guard let items = self.cachedDataStore[mutableIndexPath] else { return nil }

    let libraryItem = items[index]

    let item = MPContentItem(identifier: libraryItem.relativePath)
    item.title = libraryItem.title
    item.playbackProgress = Float(libraryItem.progress)

    ArtworkService.retrieveImageFromCache(for: libraryItem.relativePath) { result in
      let image: UIImage

      switch result {
      case .success(let value):
        image = value.image
      case .failure:
        image = self.defaultArtwork
      }

      item.artwork = MPMediaItemArtwork(boundsSize: image.size,
                                        requestHandler: { (_) -> UIImage in
        image
      })
    }

    item.subtitle = libraryItem.details

    switch libraryItem.type {
    case .book, .bound:
      item.isContainer = false
      item.isPlayable = true
    case .folder:
      item.isContainer = indexPath[0] != IndexGuide.tab.recentlyPlayed
      item.isPlayable = indexPath[0] == IndexGuide.tab.recentlyPlayed
    }

    return item
  }

  func playableContentManager(_ contentManager: MPPlayableContentManager, initiatePlaybackOfContentItemAt indexPath: IndexPath, completionHandler: @escaping (Error?) -> Void) {
    var mutableIndexPath = indexPath
    let itemIndex = mutableIndexPath.removeLast()

    guard let items = self.cachedDataStore[mutableIndexPath] else {
      completionHandler(BookPlayerError.runtimeError("carplay_library_error".localized))
      return
    }

    let libraryItem = items[itemIndex]

    let message: [AnyHashable: Any] = ["command": "play",
                                       "identifier": libraryItem.relativePath]

    NotificationCenter.default.post(name: .messageReceived, object: nil, userInfo: message)

    // Hack to show the now-playing-view on simulator
    // It has side effects on the initial state of the buttons of that view
    // But it's meant for development use only
    #if targetEnvironment(simulator)
    DispatchQueue.main.async {
      UIApplication.shared.endReceivingRemoteControlEvents()
      UIApplication.shared.beginReceivingRemoteControlEvents()
    }
    #endif

    completionHandler(nil)
  }

  func childItemsDisplayPlaybackProgress(at indexPath: IndexPath) -> Bool {
    return true
  }

  private func getItem(from items: [SimpleLibraryItem],
                       and indexPath: IndexPath) -> SimpleLibraryItem {
    var mutableIndexPath = indexPath
    let index = mutableIndexPath.removeFirst()
    let item = items[index]

    guard !mutableIndexPath.isEmpty,
          item.type == .folder,
          let folderItems = self.libraryService.fetchContents(at: item.relativePath, limit: nil, offset: nil) else {
      return item
    }

    let simpleItems = folderItems.map({ SimpleLibraryItem(from: $0,
                                                          themeAccent: themeAccent) })
    return getItem(from: simpleItems, and: mutableIndexPath)
  }

  private func getSourceItems(for index: Int) -> [SimpleLibraryItem]? {
    // Recently played items or library items
    return (index == IndexGuide.tab.recentlyPlayed
            ? self.libraryService.getLastPlayedItems(limit: 20) ?? []
            : self.libraryService.fetchContents(at: nil, limit: nil, offset: nil) ?? [])
      .map({ SimpleLibraryItem(from: $0,
                               themeAccent: themeAccent)
      })
  }

  func setNowPlayingInfo(with book: Book) {
    var identifiers = [book.identifier!]

    if let folder = book.folder {
      identifiers.append(folder.identifier)
    }

    self.cachedDataStore = [:]

    MPPlayableContentManager.shared().nowPlayingIdentifiers = identifiers
    MPPlayableContentManager.shared().reloadData()
  }
}

extension CarPlayManager: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.themeAccent = theme.linkColor
    self.defaultArtwork = ArtworkService.generateDefaultArtwork(from: theme.linkColor)!
    MPPlayableContentManager.shared().reloadData()
  }
}
