//
//  RemoteItemListView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 18/11/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI
import TipKit

struct RemoteItemListView: View {
  @Environment(\.scenePhase) var scenePhase
  @StateObject var model: RemoteItemListViewModel
  @State private var isLoading = false
  @State private var error: Error?
  @State var showPlayer = false
  @State var isRefreshing: Bool = false
  @State var isFirstLoad = true

  func getForegroundColor(for item: SimpleLibraryItem) -> Color {
    guard let lastPlayedItem = model.lastPlayedItem else { return .primary }

    if item.relativePath == lastPlayedItem.relativePath {
      return .accentColor
    }

    return item.relativePath == model.playingItemParentPath ? .accentColor : .primary
  }

  var body: some View {
    RefreshableListView(refreshing: $isRefreshing) {
      if model.folderRelativePath == nil {
        Section {
          if let lastPlayedItem = model.lastPlayedItem {
            RemoteItemListCellView(model: .init(item: lastPlayedItem, coreServices: model.coreServices)) {
              Task {
                do {
                  isLoading = true
                  try await model.coreServices.playerLoaderService.loadPlayer(lastPlayedItem.relativePath, autoplay: true)
                  showPlayer = true
                  isLoading = false
                } catch {
                  isLoading = false
                  self.error = error
                }
              }
            }
            .applyPrimaryHandGesture()
          }
        } header: {
          Text(verbatim: "watchapp_last_played_title".localized)
            .foregroundStyle(Color.accentColor)
        }
      }

      Section {
        if #available(watchOS 10.0, *),
           model.folderRelativePath == nil,
           !model.items.isEmpty
        {
          TipView(SwipeInlineTip())
            .listRowBackground(Color.clear)
        }

        ForEach(model.items) { item in
          if item.type == .folder {
            NavigationLink {
              RemoteItemListView(model: .init(
                coreServices: model.coreServices,
                folderRelativePath: item.relativePath
              ))
            } label: {
              RemoteItemListCellView(model: .init(item: item, coreServices: model.coreServices)) {}
                .allowsHitTesting(false)
                .foregroundColor(getForegroundColor(for: item))
            }
          } else {
            RemoteItemListCellView(model: .init(item: item, coreServices: model.coreServices)) {
              Task {
                do {
                  isLoading = true
                  try await model.coreServices.playerLoaderService.loadPlayer(item.relativePath, autoplay: true)
                  showPlayer = true
                  isLoading = false
                } catch {
                  isLoading = false
                  self.error = error
                }
              }
            }
          }
        }
      } header: {
        Text(verbatim: model.folderRelativePath?.components(separatedBy: "/").last ?? "library_title".localized)
          .foregroundStyle(Color.accentColor)
          .padding(.top, model.folderRelativePath == nil ? 10 : 0)
      }

      /// Create padding at the bottom
      Section {
        Spacer().frame(height: 10)
          .listRowBackground(Color.clear)
      } header: {
        Text("")
      }
      .accessibilityHidden(true)
    }
    .ignoresSafeArea(edges: [.bottom])
    .background(
      NavigationLink(destination: RemotePlayerView(coreServices: model.coreServices), isActive: $showPlayer) {
        EmptyView()
      }
      .opacity(0)
    )
    .errorAlert(error: $error)
    .overlay {
      Group {
        if isLoading {
          ProgressView()
            .tint(.white)
            .padding()
            .background(
              Color.black
                .opacity(0.9)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            )
            .ignoresSafeArea(.all)
        }
      }
    }
    .onChange(of: isRefreshing) { newValue in
      guard newValue else { return }

      Task {
        // Delay the task by 1 second to avoid jumping animations
        try await Task.sleep(nanoseconds: 1_000_000_000)
        do {
          try await model.syncListContents(ignoreLastTimestamp: true)
        } catch {
          self.error = error
        }
        isRefreshing = false
      }
    }
    .onChange(of: scenePhase) { newPhase in
      guard
        newPhase == .active,
        model.playerManager.isPlaying
      else { return }

      showPlayer = true
    }
    .onAppear {
      guard isFirstLoad else { return }
      isFirstLoad = false

      Task { @MainActor in
        do {
          try await model.syncListContents(ignoreLastTimestamp: false)
        } catch {
          self.error = error
        }
      }
    }
  }
}
