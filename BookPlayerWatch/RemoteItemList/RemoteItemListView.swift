//
//  RemoteItemListView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 18/11/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct RemoteItemListView: View {
  @ObservedObject var coreServices: CoreServices
  @State var items: [SimpleLibraryItem]
  @State var lastPlayedItem: SimpleLibraryItem?
  @State var playingItemParentPath: String?
  @State var error: Error?

  let folderRelativePath: String?

  init(
    coreServices: CoreServices,
    folderRelativePath: String? = nil
  ) {
    self.coreServices = coreServices
    let fetchedItems =
      coreServices.libraryService.fetchContents(
        at: folderRelativePath,
        limit: nil,
        offset: nil
      ) ?? []
    self._items = .init(initialValue: fetchedItems)
    let lastItem = coreServices.libraryService.getLastPlayedItems(limit: 1)?.first
    self._lastPlayedItem = .init(initialValue: lastItem)
    self.folderRelativePath = folderRelativePath

    if let lastItem {
      self._playingItemParentPath = .init(
        initialValue: getPathForParentOfItem(currentPlayingPath: lastItem.relativePath)
      )
    } else {
      self._playingItemParentPath = .init(initialValue: nil)
    }
  }

  func getForegroundColor(for item: SimpleLibraryItem) -> Color {
    guard let lastPlayedItem else { return .primary }

    if item.relativePath == lastPlayedItem.relativePath {
      return .accentColor
    }

    return item.relativePath == playingItemParentPath ? .accentColor : .primary
  }

  func getPathForParentOfItem(currentPlayingPath: String) -> String? {
    let parentFolders: [String] = currentPlayingPath.allRanges(of: "/")
      .map { String(currentPlayingPath.prefix(upTo: $0.lowerBound)) }
      .reversed()

    guard let folderRelativePath = self.folderRelativePath else {
      return parentFolders.last
    }

    guard let index = parentFolders.firstIndex(of: folderRelativePath) else {
      return nil
    }

    let elementIndex = index - 1

    guard elementIndex >= 0 else {
      return nil
    }

    return parentFolders[elementIndex]
  }

  var body: some View {
    List {
      if folderRelativePath == nil {
        Section {
          if let lastPlayedItem {
            RemoteItemListCellView(item: lastPlayedItem)
          }
        } header: {
          Text(verbatim: "watchapp_last_played_title".localized)
            .foregroundStyle(Color.accentColor)
        }
      }

      Section {
        ForEach(items) { item in
          if item.type == .folder {
            NavigationLink {
              RemoteItemListView(
                coreServices: coreServices,
                folderRelativePath: item.relativePath
              )
            } label: {
              RemoteItemListCellView(item: item)
                .foregroundColor(getForegroundColor(for: item))
            }
          } else {
            RemoteItemListCellView(item: item)
              .foregroundColor(getForegroundColor(for: item))
          }
        }
      } header: {
        Text(verbatim: folderRelativePath?.components(separatedBy: "/").last ?? "library_title".localized)
          .foregroundStyle(Color.accentColor)
      }
    }
    .errorAlert(error: $error)
    .onAppear {
      Task {
        guard
          await coreServices.syncService.canSyncListContents(
            at: folderRelativePath,
            ignoreLastTimestamp: false
          )
        else { return }

        do {
          try await coreServices.syncService.syncListContents(at: folderRelativePath)
        } catch BPSyncError.differentLastBook(let relativePath), BPSyncError.reloadLastBook(let relativePath) {
          await coreServices.syncService.setLibraryLastBook(with: relativePath)
        } catch {
          self.error = error
        }

        items =
          coreServices.libraryService.fetchContents(
            at: folderRelativePath,
            limit: nil,
            offset: nil
          ) ?? []

        lastPlayedItem = coreServices.libraryService.getLastPlayedItems(limit: 1)?.first
        if let lastPlayedItem {
          playingItemParentPath = getPathForParentOfItem(currentPlayingPath: lastPlayedItem.relativePath)
        } else {
          playingItemParentPath = nil
        }
      }
    }
  }
}
