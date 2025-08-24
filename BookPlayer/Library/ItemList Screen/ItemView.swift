//
//  ItemView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Kingfisher
import SwiftUI

struct ItemView: View {
  let item: SimpleLibraryItem

  @Environment(\.playerState) private var playerState
  @Environment(\.loadingState) private var loadingState
  @Environment(\.playerLoaderService) private var playerLoaderService
  @Environment(\.syncService) private var syncService

  @EnvironmentObject private var playerManager: PlayerManager
  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    Group {
      if item.type == .folder {
        FolderView(item: item)
      } else {
        BookView(item: item)
          .onTapGesture {
            switch syncService.getDownloadState(for: item) {
            case .downloading:
              // TODO: show alert
              print("=== cancel download of the item alert")
            case .downloaded, .notDownloaded:
              Task {
                do {
                  try await playerLoaderService.loadPlayer(item.relativePath, autoplay: true)
                  playerState.showPlayerBinding.wrappedValue = true
                } catch {
                  loadingState.error = error
                }
              }
            }
          }
      }
    }
    .listRowBackground(theme.systemBackgroundColor)
  }
}

#Preview {
  ItemView(
    item: .init(
      title: "Test",
      details: "Details",
      speed: 1,
      currentTime: 0,
      duration: 0,
      percentCompleted: 78,
      isFinished: false,
      relativePath: "",
      remoteURL: nil,
      artworkURL: nil,
      orderRank: 0,
      parentFolder: nil,
      originalFileName: "",
      lastPlayDate: nil,
      type: .book
    )
  )
  .environmentObject(ThemeViewModel())
}
