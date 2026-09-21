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
    /// A download/verification failure (e.g. a discarded truncated file) must reset
    /// the cell — otherwise, now that completion is gated on verification, it would
    /// stay stuck on the progress spinner until the view recomputes from disk. The
    /// error payload only carries `relativePath`, so this matches the item directly
    /// (a bound-book child error doesn't reset the parent cell — same limitation as
    /// the Watch).
    .onReceive(
      syncService.downloadErrorPublisher
        .filter { $0.0 == item.relativePath }
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
        downloadBadge
          .padding(1)
          .padding(.trailing, 2)
          .foregroundStyle(theme.linkColor)
      }
      .clipShape(CornerTriangle())
    }
  }

  /// The server this row would stream from, or nil when it isn't a media-server item.
  ///
  /// `streamingResource` rather than the first media-server link, for two reasons. It is the
  /// same value `downloadRemoteFiles` picks, so the badge always names the server the tap will
  /// actually reach. And it is already Hardcover-filtered: the API's `markExternalSourceUploaded`
  /// marks EVERY provider row of an item 'downloaded', so a dual-linked book's Hardcover row
  /// passes a bare syncStatus check — which once aimed the download at a provider that has no
  /// files at all.
  private var streamingServer: ExternalResource.MediaServerProvider? {
    item.externalResources?.streamingResource?.mediaServer
  }

  /// What sits in the corner while the file isn't on the device.
  ///
  /// `cloud` is right for our own storage and wrong for a media server — the file is on the
  /// user's machine, not ours, which is the distinction the media-server paywall copy makes a
  /// point of. The provider's mark says the same thing the cloud does, and says whose.
  ///
  /// All three badges share the cloud's 14pt-wide box so they land on ONE axis. The width is
  /// what centres them: a height-only frame lets each mark's own width decide where its centre
  /// falls, and the marks differ enough (Jellyfin is square, Audiobookshelf is taller than
  /// wide) that they sat 1.6pt and 2.9pt right of the cloud — visibly off against a cloud row
  /// above. Inside a shared box each one centres itself, whatever its aspect ratio.
  ///
  /// The 3pt below buys what the cloud gets for free. `cloud` is a wide, low glyph, so fitting
  /// it into a 14x16 box letterboxes it and leaves ~4.6pt of air under its ink; a mark that
  /// fills its box lands flush on the corner's edge instead and reads as sitting lower.
  ///
  /// The heights themselves are per-provider — see `MediaServerProvider.badgeHeight`.
  @ViewBuilder
  private var downloadBadge: some View {
    if let streamingServer {
      Image(streamingServer.icon)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 14, height: streamingServer.badgeHeight)
        .padding(.bottom, 3)
    } else {
      Image(systemName: "cloud")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 14, height: 16)
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
