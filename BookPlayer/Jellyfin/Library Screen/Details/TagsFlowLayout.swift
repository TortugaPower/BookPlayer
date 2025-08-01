//
//  TagsFlowLayout.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 31/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct TagsFlowLayout: Layout {
  var alignment: HorizontalAlignment = .leading
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    var height: CGFloat = 0
    var rowHeight: CGFloat = 0
    var rowWidth: CGFloat = 0

    let maxWidth = proposal.width ?? .infinity

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)

      if rowWidth + size.width > maxWidth {
        // move to next row
        height += rowHeight + spacing
        rowWidth = 0
        rowHeight = 0
      }

      rowWidth += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }

    height += rowHeight

    return CGSize(width: maxWidth, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var x: CGFloat = bounds.minX
    var y: CGFloat = bounds.minY
    var rowHeight: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)

      if x + size.width > bounds.maxX {
        x = bounds.minX
        y += rowHeight + spacing
        rowHeight = 0
      }

      subview.place(
        at: CGPoint(x: x, y: y),
        proposal: ProposedViewSize(width: size.width, height: size.height)
      )

      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
  }
}
