//
//  LibraryTileView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 14/10/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

/// A library item in a grid layout. As a card: its cover, then its duration, title and author (or
/// file count). As a cover: the cover alone. Either way the cover's corner shows its progress as a
/// list row does. What a tap does is up to the grid
struct LibraryTileView: View {
  enum Style {
    case card
    case cover
  }

  /// The cover's width over its height: square, as audiobook covers are (the web app's cards
  /// use 10:9)
  static let coverAspectRatio: CGFloat = 1

  let item: SimpleLibraryItem
  let style: Style
  /// Only while the list is selecting: the tile shows whether it's selected
  let isSelecting: Bool
  let isSelected: Bool

  @Environment(\.syncService) private var syncService
  @Environment(\.playingItemParentPath) private var playingItemParentPath
  @Environment(\.playerState) private var playerState
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @EnvironmentObject private var theme: ThemeViewModel

  @AppStorage(
    wrappedValue: false,
    Constants.UserDefaults.libraryDisplayTitleSource,
    store: UserDefaults(suiteName: Constants.ApplicationGroupIdentifier)
  )
  private var useOriginalFileName: Bool

  @AppStorage(
    wrappedValue: false,
    Constants.UserDefaults.libraryDisplayProgressStyle,
    store: UserDefaults(suiteName: Constants.ApplicationGroupIdentifier)
  )
  private var progressAsPercentage: Bool

  /// A folder's stack and a card's progress mark are sized from it: the whole cell's width
  @State private var coverWidth: CGFloat = 0

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: style == .card ? 16 : 8, style: .continuous)
  }

  /// The loaded book, or the folder here that holds it, as in a list row
  private var isHighlighted: Bool {
    playerState.loadedBookRelativePath == item.relativePath || playingItemParentPath == item.relativePath
  }

  var body: some View {
    ItemProgressReader(item: item) { progress, isFinished in
      Group {
        switch style {
        case .card:
          VStack(alignment: .leading, spacing: 0) {
            cover(progress: isFinished ? 1 : progress)
            details
          }
          /// As tall as the tallest card in its row, which the grid sizes the row to, so a row
          /// lines up while each fits its own text
          .frame(maxHeight: .infinity, alignment: .top)
          .background(theme.tertiarySystemBackgroundColor)
          .clipShape(shape)
        case .cover:
          cover(progress: isFinished ? 1 : progress)
            .clipShape(shape)
        }
      }
      .background(alignment: .top) {
        if item.type == .folder {
          stackedCopies
        }
      }
      .padding(.top, 2 * stackStep)
      /// Around the stack too, so a folder lifts into its menu or a drag with its leaves
      .contentShape(shape)
      .contentShape(.contextMenuPreview, shape)
      .contentShape(.dragPreview, shape)
    }
    /// Only a real change: the tile's layout depends on this width, and in a right-to-left layout
    /// it can come back a rounding error apart on every pass, which would never settle
    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
      if abs(width - coverWidth) >= 0.5 {
        coverWidth = width
      }
    }
    .accessibilityElement(children: .ignore)
    .dynamicAccessibilityLabel(for: item)
    .accessibilityAddTraits(isSelecting && isSelected ? .isSelected : [])
  }

  /// A folder's cover is a stack: two dimmed copies of it peek above it, each a step narrower.
  /// The front one is as wide as a book's and shorter by the stack's height, so the whole tile is
  /// as tall as a book's and the rows still line up
  private var stackStep: CGFloat {
    item.type == .folder ? (coverWidth * 0.045).rounded() : 0
  }

  /// The front cover's width over its height
  private var frontAspectRatio: CGFloat {
    let height = coverWidth / Self.coverAspectRatio - 2 * stackStep
    return height > 0 ? coverWidth / height : Self.coverAspectRatio
  }

  private func cover(progress: Double) -> some View {
    ItemArtworkView(
      item: item,
      isHighlighted: isHighlighted,
      syncService: syncService,
      style: style == .card ? .tile : .cover,
      aspectRatio: frontAspectRatio,
      /// Not cropped to the shorter shape: fitted, on a blurred copy of itself
      contentMode: item.type == .folder ? .fit : .fill
    )
    .overlay(alignment: .topLeading) {
      /// On the cover itself, a folder's below its stack. The bottom corner is the download
      /// badge's, as in a list row
      if !isSelecting {
        progressMark(progress: progress)
          .padding(Spacing.S2)
      }
    }
    .overlay {
      if isSelecting {
        selectionMark
      }
    }
  }

  /// The two leaves behind a folder's tile, above it on the page (not on a card's background),
  /// the furthest one the darkest. The default artwork, dimmed: they show at once, with nothing to
  /// load
  private var stackedCopies: some View {
    ZStack(alignment: .top) {
      stackedCopy(level: 2, dimming: 0.45)
      stackedCopy(level: 1, dimming: 0.25)
    }
  }

  private func stackedCopy(level: CGFloat, dimming: Double) -> some View {
    Color.black
      .aspectRatio(Self.coverAspectRatio, contentMode: .fit)
      .overlay {
        theme.defaultArtwork?
          .resizable()
          .aspectRatio(contentMode: .fill)
      }
      .overlay(Color.black.opacity(dimming))
      .clipShape(RoundedRectangle(cornerRadius: style == .card ? 12 : 6, style: .continuous))
      .padding(.horizontal, level * stackStep)
      .offset(y: -level * stackStep)
  }

  private var details: some View {
    VStack(alignment: .leading, spacing: Spacing.S5) {
      Text(verbatim: item.durationFormatted)
        .bpFont(.caption)
        .foregroundStyle(theme.secondaryColor)
        .lineLimit(1)
      Text(verbatim: item.displayTitle(useOriginalFileName: useOriginalFileName))
        .bpFont(.subheadline)
        .fontWeight(.bold)
        .foregroundStyle(isHighlighted ? theme.linkColor : theme.primaryColor)
        .lineLimit(titleLineLimit)
      Text(verbatim: item.details)
        .bpFont(.caption)
        .foregroundStyle(theme.secondaryColor)
        .lineLimit(2)
    }
    .multilineTextAlignment(.leading)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, Spacing.S1)
    .padding(.top, Spacing.S3)
    .padding(.bottom, Spacing.S2 + Spacing.S5)
  }

  /// A third line at the accessibility sizes, where wrapping beats cutting a title short
  private var titleLineLimit: Int {
    dynamicTypeSize.isAccessibilitySize ? 3 : 2
  }

  /// A card's wheel grows from the list's to 15% of the card's width, about the share the list's
  /// size takes of a cover alone, which stays at it. The wheel draws 19.5pt across: its 18pt frame
  /// plus the outline's outer half (the finished disc draws 19pt, sized by its check)
  private var wheelScale: CGFloat {
    style == .card ? max(1, coverWidth * 0.15 / 19.5) : 1
  }

  /// A list row's progress mark as it is (the wheel, or the percentage with that setting; the
  /// check once finished; nothing before it's started), on the list's background, lifted off the
  /// cover by the shadow the player's AirPlay button has
  @ViewBuilder
  private func progressMark(progress: Double) -> some View {
    /// Non-finite while a duration is still 0, as `PercentageProgressView` guards
    let progress = progress.isFinite ? min(max(progress, 0), 1) : 0

    if progress > 0 {
      Group {
        if progressAsPercentage, progress < 1 {
          /// Sized by its font alone, never scaled, so it follows the text size: as tall as the
          /// wheel over a cover alone, and the title's size on a card, never larger
          PercentageProgressView(
            progress: progress,
            isHighlighted: isHighlighted,
            font: style == .card ? .miniPlayerTitle : .captionSemibold
          )
            .padding(.horizontal, Spacing.S3)
            .padding(.vertical, Spacing.S5)
            .background(theme.systemBackgroundColor, in: Capsule())
        } else {
          CircularProgressView(progress: progress, isHighlighted: isHighlighted)
            .background {
              /// Under the gap inside the wheel's outline, and the outline's outer half, drawn
              /// past its frame. The finished disc is opaque already
              if progress < 1 {
                Circle().inset(by: -0.75).fill(theme.systemBackgroundColor)
              }
            }
            .scaleEffect(wheelScale, anchor: .topLeading)
        }
      }
      /// One shadow for the whole mark, not one per layer inside it
      .compositingGroup()
      .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
    }
  }

  /// As in Files: a ring in the middle of the cover, filled with a check once selected, over a
  /// gray wash
  private var selectionMark: some View {
    ZStack {
      if isSelected {
        Color.gray.opacity(0.5)
      }
      ZStack {
        Circle()
          .fill(isSelected ? theme.linkColor : Color.black.opacity(0.15))
        Circle()
          .strokeBorder(Color.white, lineWidth: 2)
        if isSelected {
          Image(systemName: "checkmark")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .fontWeight(.bold)
            .foregroundStyle(Color.white)
            .padding(8)
        }
      }
      .frame(width: 30, height: 30)
      .shadow(radius: 2)
    }
  }
}
