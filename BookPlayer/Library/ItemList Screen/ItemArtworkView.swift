//
//  ItemArtworkView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 23/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Kingfisher
import SwiftUI

struct ItemArtworkView: View {
  private let item: SimpleLibraryItem
  private let isHighlighted: Bool
  private let syncService: SyncService
  @State private var downloadState: DownloadState

  init(
    item: SimpleLibraryItem,
    isHighlighted: Bool,
    syncService: SyncService
  ) {
    self.item = item
    self.isHighlighted = isHighlighted
    self.syncService = syncService

    self._downloadState = .init(initialValue: syncService.getDownloadState(for: item))
  }

  @State private var artworkReloadBump = false

  @Environment(\.libraryNode) private var libraryNode
  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    ZStack {
      Color.black
      if let artworkURL = item.artworkURL {
        KFImage
          .resource(
            KF.ImageResource(downloadURL: artworkURL, cacheKey: item.relativePath)
          )
          .placeholder {
            theme.defaultArtwork
          }
          .targetCache(ArtworkService.cache)
          .resizable()
          .aspectRatio(contentMode: .fit)
      } else {
        KFImage
          .dataProvider(
            ArtworkService.getArtworkProvider(
              for: item.relativePath,
              remoteURL: item.remoteURL
            )
          )
          .placeholder {
            theme.defaultArtwork
          }
          .targetCache(ArtworkService.cache)
          .resizable()
          .aspectRatio(contentMode: .fit)
      }
    }
    .frame(width: 50, height: 50)
    .overlay {
      ZStack {
        overlayView
        if isHighlighted {
          theme.linkColor.opacity(0.3)
        }
      }
      .allowsHitTesting(false)
    }
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    .mask(RoundedRectangle(cornerRadius: 4))
    .id(artworkReloadBump)
    .onReceive(
      ArtworkService.artworkUpdatePublisher
        .filter { $0 == item.relativePath }
    ) { _ in
      artworkReloadBump.toggle()
      downloadState = syncService.getDownloadState(for: item)
    }
    .onReceive(
      syncService.downloadProgressPublisher
        .filter { $0.1 == libraryNode?.folderRelativePath || $0.2 == libraryNode?.folderRelativePath }
        .filter { $0.0 == item.relativePath || $0.1 == item.relativePath }
        .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: false)
    ) { (_, _, _, progress) in
      downloadState = .downloading(progress: progress)
    }
    .onReceive(
      syncService.downloadCompletedPublisher
        .filter { $0.1 == libraryNode?.folderRelativePath || $0.2 == libraryNode?.folderRelativePath }
        .filter { $0.0 == item.relativePath || $0.1 == item.relativePath }
    ) { _ in
      downloadState = .downloaded
    }
    .onReceive(
      syncService.downloadCancelledPublisher
        .filter { $0.1 == libraryNode?.folderRelativePath || $0.2 == libraryNode?.folderRelativePath }
        .filter { $0.0 == item.relativePath || $0.1 == item.relativePath }
    ) { _ in
      downloadState = .notDownloaded
    }
  }

  @ViewBuilder
  var overlayView: some View {
    switch downloadState {
    case .downloading(let progress):
      ZStack {
        theme.systemBackgroundColor
          .opacity(0.3)
        CircularProgressView(
          progress: progress,
          isHighlighted: isHighlighted
        )
      }
    case .downloaded:
      EmptyView()
    case .notDownloaded:
      ZStack(alignment: .bottomTrailing) {
        CornerTriangle()
          .fill(theme.systemGroupedBackgroundColor)
        Image(systemName: "cloud")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 14, height: 16)
          .padding(1)
          .padding(.trailing, 2)
          .foregroundStyle(theme.linkColor)
      }
      .clipShape(CornerTriangle())
    }
  }
}

/// Bottom-right angled triangle
struct CornerTriangle: Shape {
  var fraction: CGFloat = 1 / 3

  func path(in rect: CGRect) -> Path {
    var p = Path()
    let x0 = rect.maxX
    let y0 = rect.maxY
    p.move(to: CGPoint(x: x0, y: y0))
    p.addLine(to: CGPoint(x: rect.width * fraction, y: y0))
    p.addLine(to: CGPoint(x: x0, y: rect.height * fraction))
    p.closeSubpath()
    return p
  }
}
