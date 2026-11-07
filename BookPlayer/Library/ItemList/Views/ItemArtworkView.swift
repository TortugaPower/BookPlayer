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
  enum Style {
    /// 50 pt, beside a list row's text
    case row
    /// The width of a grid tile, as tall as `LibraryTileView.coverAspectRatio` makes it; the tile
    /// rounds its corners
    case tile
    /// As `tile`, alone in the covers grid: with no artwork, the title and author show on the
    /// default one, since nothing else on screen names the item
    case cover
  }

  private let item: SimpleLibraryItem
  private let isHighlighted: Bool
  private let syncService: SyncService
  private let style: Style
  /// A tile's width over its height: a folder's front cover is shorter than a book's, to make room
  /// for its stack
  private let aspectRatio: CGFloat
  /// How a tile's artwork meets that shape (a row's always fits)
  private let contentMode: SwiftUI.ContentMode
  @State private var downloadState: DownloadState

  init(
    item: SimpleLibraryItem,
    isHighlighted: Bool,
    syncService: SyncService,
    style: Style = .row,
    aspectRatio: CGFloat = LibraryTileView.coverAspectRatio,
    contentMode: SwiftUI.ContentMode = .fill
  ) {
    self.item = item
    self.isHighlighted = isHighlighted
    self.syncService = syncService
    self.style = style
    self.aspectRatio = aspectRatio
    self.contentMode = contentMode

    self._downloadState = .init(initialValue: syncService.getDownloadState(for: item))
  }

  @State private var artworkReloadBump = false

  @Environment(\.libraryNode) private var libraryNode
  @Environment(\.displayScale) private var displayScale
  @EnvironmentObject private var theme: ThemeViewModel

  @AppStorage(
    wrappedValue: false,
    Constants.UserDefaults.libraryDisplayTitleSource,
    store: UserDefaults(suiteName: Constants.ApplicationGroupIdentifier)
  )
  private var useOriginalFileName: Bool

  var body: some View {
    Group {
      switch style {
      case .row:
        ZStack {
          Color.black
          artworkImage
        }
        .frame(width: 50, height: 50)
      case .tile, .cover:
        /// Filled and cropped by default, so a cover that isn't the tile's shape still covers it
        Color.black
          .aspectRatio(aspectRatio, contentMode: .fit)
          .overlay {
            artworkImage
          }
          .clipped()
      }
    }
    .overlay {
      ZStack {
        overlayView
        if isHighlighted {
          theme.linkColor.opacity(0.3)
        }
      }
      .allowsHitTesting(false)
    }
    .modifier(RowArtworkCorners(isEnabled: style == .row))
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
  private var artworkImage: some View {
    if let artworkURL = item.artworkURL {
      tileOptions(
        KFImage
          .resource(
            KF.ImageResource(downloadURL: artworkURL, cacheKey: item.relativePath)
          )
      )
      .placeholder {
        placeholder
      }
      .targetCache(ArtworkService.cache)
      .resizable()
      .contentConfigure { loadedArtwork($0) }
    } else {
      tileOptions(
        KFImage
          .dataProvider(
            ArtworkService.getArtworkProvider(
              for: item.relativePath,
              remoteURL: item.remoteURL
            )
          )
      )
      .placeholder {
        placeholder
      }
      .targetCache(ArtworkService.cache)
      .resizable()
      .contentConfigure { loadedArtwork($0) }
    }
  }

  /// A tile shows many covers at once: each is decoded at the tile's size, not the cover's full
  /// resolution. The original is still cached under the item's path, where the widgets read it
  private func tileOptions(_ image: KFImage) -> KFImage {
    guard style != .row else { return image }

    return image
      .setProcessor(ArtworkService.tileProcessor)
      .scaleFactor(displayScale)
      .cacheOriginalImage()
  }

  @ViewBuilder
  private var placeholder: some View {
    switch style {
    case .row:
      theme.defaultArtwork
    case .tile:
      theme.defaultArtwork?
        .resizable()
        .aspectRatio(contentMode: .fill)
    case .cover:
      /// As the player's placeholder: the author, then the title, in white at the bottom of the
      /// tile (not of the artwork, which overflows a tile that isn't square)
      Color.clear
        .overlay {
          theme.defaultArtwork?
            .resizable()
            .aspectRatio(contentMode: .fill)
        }
        .clipped()
        .overlay(alignment: .bottomLeading) {
          VStack(alignment: .leading, spacing: Spacing.S5) {
            Text(verbatim: item.details)
              .bpFont(.caption)
              .opacity(0.7)
              .lineLimit(1)
            Text(verbatim: item.displayTitle(useOriginalFileName: useOriginalFileName))
              .bpFont(.caption)
              .fontWeight(.bold)
              .lineLimit(3)
          }
          .multilineTextAlignment(.leading)
          .foregroundStyle(Color.white)
          .padding(Spacing.S2)
        }
    }
  }

  /// The artwork once loaded; the default one, while there's none, is the placeholder's. A row's
  /// fits. Fitted in a tile, it sits on a blurred copy of itself filling the tile, as the player's
  /// artwork background does, rather than on bars: the one image drawn twice, so both show at once
  @ViewBuilder
  private func loadedArtwork(_ image: Image) -> some View {
    if style != .row, contentMode == .fit {
      /// `Color.clear` takes the tile's size, so the filled copy overflows it and is clipped
      Color.clear
        .overlay {
          image
            .aspectRatio(contentMode: .fill)
            .blur(radius: 12, opaque: true)
        }
        .clipped()
        .overlay {
          image
            .aspectRatio(contentMode: .fit)
        }
    } else {
      image
        .aspectRatio(contentMode: style == .row ? .fit : contentMode)
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
          isHighlighted: isHighlighted,
          length: style == .row ? 18 : 36
        )
      }
    case .downloaded:
      EmptyView()
    case .notDownloaded:
      switch style {
      case .row:
        downloadCorner(scale: 1)
      case .tile, .cover:
        /// The list's corner grown with the cover: its triangle runs 30% along each edge of a
        /// cover alone and 25% of a card's wider one (two thirds of its box), where on a 50 pt row
        /// it runs two thirds
        GeometryReader { proxy in
          let box = proxy.size.width * (style == .cover ? 0.3 : 0.25) * 1.5
          downloadCorner(scale: box / 50)
            .frame(width: box, height: box)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
      }
    }
  }

  /// `scale` 1 is a list row's, drawn in a 50 pt box
  private func downloadCorner(scale: CGFloat) -> some View {
    ZStack(alignment: .bottomTrailing) {
      CornerTriangle()
        .fill(theme.systemGroupedBackgroundColor)
      downloadBadge(scale: scale)
        .padding(1 * scale)
        .padding(.trailing, 2 * scale)
        .foregroundStyle(theme.linkColor)
    }
    .clipShape(CornerTriangle())
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
  private func downloadBadge(scale: CGFloat) -> some View {
    if let streamingServer {
      Image(streamingServer.icon)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 14 * scale, height: streamingServer.badgeHeight * scale)
        .padding(.bottom, 3 * scale)
    } else {
      Image(systemName: "cloud")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 14 * scale, height: 16 * scale)
    }
  }
}

/// A list row's artwork has rounded corners of its own; a tile's cover is rounded by its tile
private struct RowArtworkCorners: ViewModifier {
  let isEnabled: Bool

  func body(content: Content) -> some View {
    if isEnabled {
      content
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .mask(RoundedRectangle(cornerRadius: 4))
    } else {
      content
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
