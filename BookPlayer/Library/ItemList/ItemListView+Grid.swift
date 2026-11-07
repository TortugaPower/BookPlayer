//
//  ItemListView+Grid.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 14/10/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

/// The grid layouts (cards, or covers only): the list's items as tiles. Where the list relies on
/// `List`, the grid has its own: a long press opens the item's options (the list's swipe), a tap
/// toggles the selection while selecting, and a tile dragged on from a long press moves (the iOS 27
/// reorder container, for the list's `onMove`)
extension ItemListView {
  @ViewBuilder
  var tileGrid: some View {
    if #available(iOS 27.0, *) {
      tileScroll { visibleHeight in
        LazyVGrid(columns: tileColumns, spacing: tileSpacing) {
          ForEach(model.filteredResults) { item in
            tile(item)
          }
          .reorderable()
        }
        /// A grid centers fixed columns in its width: given just theirs, the inset places them
        .frame(width: foldedTileColumns?.width)
        .padding(.leading, foldedTileColumns?.leadingInset ?? 0)
        /// The whole screen at least, so a file (or a tile, to the end) can drop below the last tiles
        .frame(
          maxWidth: .infinity,
          minHeight: visibleHeight,
          alignment: foldedTileColumns == nil ? .top : .topLeading
        )
        .onGeometryChange(for: TileGridFold?.self) { proxy in
          Self.tileGridFold(in: proxy)
        } action: { fold in
          tileGridFold = fold
        }
        /// Never on a filtered subset, which would corrupt the order, as in the list
        .reorderContainer(for: SimpleLibraryItem.self, isEnabled: !model.isFiltering) { difference in
          moveTiles(difference)
        }
        /// Right after the reorder container, where Apple's reorder docs place a drop destination for
        /// other apps' items: on any ancestor (even the scroll view) a dropped tile lands off its slot
        .acceptsDroppedFiles()
        /// A file from another app is a copy (its "+" badge), a tile moved here is a move: in the
        /// reorder container every drop otherwise reads as a move
        .dropConfiguration { session in
          DropConfiguration(operation: session.localSession == nil ? .copy : .move)
        }
        .padding(.horizontal, Spacing.S)
      }
    } else {
      /// No reordering here before iOS 27: the list layout has it
      tileScroll { _ in
        LazyVGrid(columns: tileColumns, spacing: tileSpacing) {
          ForEach(model.filteredResults, id: \.id) { item in
            tile(item)
          }
        }
        .padding(.horizontal, Spacing.S)
      }
      .acceptsDroppedFiles()
    }
  }

  private func tileScroll<Grid: View>(
    @ViewBuilder grid: @escaping (_ visibleHeight: CGFloat) -> Grid
  ) -> some View {
    VisibleHeightScrollView { visibleHeight in
      grid(visibleHeight)

      if model.canLoadMore {
        /// It loads the first page too, as the list's last row does
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
          .accessibilityHidden(true)
          .task { await model.loadNextPage() }
      }
    }
  }

  /// As many columns as fit tiles of about 150 pt (cards) or 100 pt (covers, 140 pt on a wide
  /// screen), which grow with the text size: at the largest sizes one or two columns, capped so a
  /// tile never overflows a narrow window. Across a fold, columns that leave it in a gap
  private var tileColumns: [GridItem] {
    if let foldedTileColumns {
      return foldedTileColumns.gridItems
    }

    return [GridItem(.adaptive(minimum: tileMinimumWidthForLayout), spacing: tileSpacing, alignment: .top)]
  }

  private var tileMinimumWidthForLayout: CGFloat {
    let minimumWidth =
      switch layout {
      case .covers: horizontalSizeClass == .regular ? wideCoverMinimumWidth : coverMinimumWidth
      case .grid, .list: tileMinimumWidth
      }

    guard ProcessInfo.processInfo.isiOSAppOnMac else {
      return min(minimumWidth, 280)
    }

    /// A Mac draws the app at 77% and is viewed from farther away: tiles there are as large as on
    /// an iPad, and grow with the Text Size setting as the fonts do
    let macScale: CGFloat = 1.3
    let textScale = BPFontModifier.macOSScaleFactor(forIndex: macOSTextScaleIndex)
    return min(minimumWidth * macScale * textScale, 280 * macScale)
  }

  private var foldedTileColumns: FoldedTileColumns? {
    guard let tileGridFold else { return nil }

    return FoldedTileColumns(
      width: tileGridFold.width,
      fold: tileGridFold.fold,
      minimumWidth: tileMinimumWidthForLayout,
      spacing: tileSpacing
    )
  }

  /// A fold running top to bottom across the grid, in the grid's coordinates (iPhone Duo half open
  /// in landscape). Flat, closed or across the screen there's none to avoid
  private static func tileGridFold(in proxy: GeometryProxy) -> TileGridFold? {
    guard #available(iOS 27.1, *) else { return nil }

    guard
      let fold = proxy.reservedRegions(kind: .division)
        .first(where: { $0.isActive && $0.frame.height > $0.frame.width })?
        .frame
    else {
      return nil
    }

    return TileGridFold(width: proxy.size.width, fold: fold.minX...fold.maxX)
  }

  private var tileSpacing: CGFloat {
    layout == .covers ? Spacing.S2 : Spacing.S
  }

  @ViewBuilder
  private func tile(_ item: SimpleLibraryItem) -> some View {
    let isSelecting = model.editMode.isEditing
    let tileView = LibraryTileView(
      item: item,
      style: layout == .covers ? .cover : .card,
      isSelecting: isSelecting,
      isSelected: model.selectedSetItems.contains(item.id)
    )

    /// A ZStack, not a Group: on iOS 27.0, lifting a reorderable item whose view comes down to a
    /// conditional (an `if` or `switch` with only modifiers above it) crashes in SwiftUI
    /// ("Unexpected identifier type"). A container above the conditional avoids it
    ZStack {
      if item.type == .folder, !isSelecting {
        NavigationLink(
          value: LibraryNode.folder(title: item.title, relativePath: item.relativePath, uuid: item.uuid)
        ) {
          tileView
        }
      } else {
        /// A book's one button, selecting or not, so toggling Select doesn't rebuild its tile
        Button {
          if isSelecting {
            toggleSelection(of: item)
          } else {
            handleTap(on: item)
          }
        } label: {
          tileView
        }
      }
    }
    .buttonStyle(.plain)
    .contextMenu {
      if !isSelecting {
        if layout == .covers {
          /// Named, since a cover alone doesn't say which item it is
          Section {
            contextMenuContent(for: [item])
          } header: {
            Text(verbatim: item.displayTitle(useOriginalFileName: useOriginalFileName))
          }
        } else {
          contextMenuContent(for: [item])
        }
      }
    }
    /// The list's swipe actions, which VoiceOver offers there as actions; none while selecting, when
    /// the list hides its swipe actions too
    .accessibilityActions {
      if !isSelecting {
        Button("options_button") {
          model.selectedSetItems = [item.id]
          activeConfirmationDialog = .itemOptions
        }
        Button("delete_button") {
          model.selectedSetItems = [item.id]
          activeAlert = .delete
        }
      }
    }
    .accessibilityRotorEntry(id: item.id, in: customRotorNamespace)
    /// For the release-check UI tests, as on the list's rows
    .accessibilityIdentifier("library.row.\(item.relativePath)")
    .onAppear {
      Task {
        await model.prefetchIfNeeded(for: item)
      }
    }
  }

  @available(iOS 27.0, *)
  private func moveTiles(
    _ difference: ReorderDifference<SimpleLibraryItem.ID, ReorderableSingleCollectionIdentifier>
  ) {
    switch difference.destination.position {
    case .before(let id):
      model.reorderItems(ids: difference.sources, before: id)
    case .end:
      model.reorderItems(ids: difference.sources, before: nil)
    }
  }
}

/// A scroll view whose content gets its visible height, kept in its own state: it follows the scroll
/// view's insets, which a collapsing large title moves while scrolling, and that shouldn't redraw
/// the whole list screen
private struct VisibleHeightScrollView<Content: View>: View {
  @ViewBuilder let content: (_ visibleHeight: CGFloat) -> Content

  @State private var visibleHeight: CGFloat = 0

  var body: some View {
    ScrollView {
      content(visibleHeight)
    }
    .onScrollGeometryChange(for: CGFloat.self) { geometry in
      geometry.containerSize.height - geometry.contentInsets.top - geometry.contentInsets.bottom
    } action: { _, height in
      visibleHeight = max(floor(height), 0)
    }
  }
}

/// The grid's width, and the span a fold takes across it, in the grid's coordinates
struct TileGridFold: Equatable {
  let width: CGFloat
  let fold: ClosedRange<CGFloat>
}

/// Columns that leave a fold in the gap between two of them. Every tile is one width (tiles of
/// different widths have different heights, and the rows would no longer line up): as many as fit
/// on each side of the fold, with the space left over at the outer edges, away from it
struct FoldedTileColumns: Equatable {
  let tileWidth: CGFloat
  let leadingCount: Int
  let trailingCount: Int
  let spacing: CGFloat
  /// Between the last column before the fold and the first after it
  let foldGap: CGFloat
  /// Before the first column
  let leadingInset: CGFloat

  /// Nil when a side of the fold can't hold a tile of `minimumWidth`
  init?(width: CGFloat, fold: ClosedRange<CGFloat>, minimumWidth: CGFloat, spacing: CGFloat) {
    let leadingSpace = fold.lowerBound
    let trailingSpace = width - fold.upperBound
    guard leadingSpace >= minimumWidth, trailingSpace >= minimumWidth else { return nil }

    func columns(in space: CGFloat) -> Int {
      max(1, Int((space + spacing) / (minimumWidth + spacing)))
    }
    func widestTile(in space: CGFloat, columns: Int) -> CGFloat {
      (space - CGFloat(columns - 1) * spacing) / CGFloat(columns)
    }

    let leadingCount = columns(in: leadingSpace)
    let trailingCount = columns(in: trailingSpace)
    let tileWidth = min(
      widestTile(in: leadingSpace, columns: leadingCount),
      widestTile(in: trailingSpace, columns: trailingCount)
    ).rounded(.down)

    self.tileWidth = tileWidth
    self.leadingCount = leadingCount
    self.trailingCount = trailingCount
    self.spacing = spacing
    self.foldGap = fold.upperBound - fold.lowerBound
    self.leadingInset = leadingSpace - CGFloat(leadingCount) * tileWidth - CGFloat(leadingCount - 1) * spacing
  }

  /// The columns and the gaps between them
  var width: CGFloat {
    CGFloat(leadingCount + trailingCount) * tileWidth
      + CGFloat(leadingCount + trailingCount - 2) * spacing
      + foldGap
  }

  var gridItems: [GridItem] {
    (0..<leadingCount + trailingCount).map { column in
      GridItem(
        .fixed(tileWidth),
        spacing: column == leadingCount - 1 ? foldGap : spacing,
        alignment: .top
      )
    }
  }
}
