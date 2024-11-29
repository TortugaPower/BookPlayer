//
//  AdaptiveVGrid.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-21.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI

/// A view to display items in a grid, while adapting to the available space, item size, and number of items.
/// When items can fit in one row or column, prefer that (depending on whether we have more horizontal or vertical space).
/// Otherwise uses a LazyVGrid insize a ScrollView to display the content.
///
/// content should have the number of subviews specified as numItems.
struct AdaptiveVGrid<Content: View>: View {
  var numItems: Int
  var itemMinSize: CGSize
  var itemMaxSize: CGSize
  var itemSpacing: CGFloat
  var content: Content
  
  public init(
    numItems: Int,
    itemMinSize: CGSize,
    itemMaxSize: CGSize,
    itemSpacing: CGFloat,
    @ViewBuilder content: () -> Content
  ) {
    self.numItems = numItems
    self.itemMinSize = itemMinSize
    self.itemMaxSize = itemMaxSize
    self.itemSpacing = itemSpacing
    self.content = content()
  }
  
  var body: some View {
    GeometryReader { geometry in
      bodyImpl(availableSize: geometry.size)
        .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
    }
  }
  
  @ViewBuilder
  func bodyImpl(availableSize: CGSize) -> some View {
    let widthRatio = availableSize.width / (CGFloat(numItems) * itemMaxSize.width + CGFloat(numItems - 1) * itemSpacing)
    let heightRatio = availableSize.height / (CGFloat(numItems) * itemMaxSize.height + CGFloat(numItems - 1) * itemSpacing)
    
    if widthRatio >= heightRatio && availableSize.width >= (CGFloat(numItems) * itemMinSize.width + CGFloat(numItems - 1) * itemSpacing) {
      HStack(spacing: itemSpacing) { content }
    } else if heightRatio >= widthRatio && availableSize.height >= (CGFloat(numItems) * itemMinSize.height + CGFloat(numItems - 1) * itemSpacing) {
      VStack(spacing: itemSpacing) { content }
    } else {
      ScrollView {
        let columns = [GridItem(.adaptive(minimum: itemMinSize.width, maximum: itemMaxSize.width), spacing: itemSpacing)]
        LazyVGrid(columns: columns, alignment: .center) {
          content
        }
        .frame(minWidth: availableSize.width, minHeight: availableSize.height)
      }
    }
  }
}
