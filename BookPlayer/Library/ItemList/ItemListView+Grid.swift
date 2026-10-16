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
        /// The whole screen at least, so a file (or a tile, to the end) can drop below the last tiles
        .frame(maxWidth: .infinity, minHeight: visibleHeight, alignment: .top)
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

  /// As many columns as fit tiles of about 150 pt (cards) or 100 pt (covers), which grow with the
  /// text size: at the largest sizes one or two columns, capped so a tile never overflows a narrow
  /// window
  private var tileColumns: [GridItem] {
    let minimumWidth = layout == .covers ? coverMinimumWidth : tileMinimumWidth
    return [GridItem(.adaptive(minimum: min(minimumWidth, 280)), spacing: tileSpacing, alignment: .top)]
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
