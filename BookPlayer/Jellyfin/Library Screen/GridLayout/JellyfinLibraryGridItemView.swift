//
//  JellyfinLibraryGridItemView.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-28.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Kingfisher
import SwiftUI

struct JellyfinLibraryGridItemView: View {
  @Environment(\.editMode) private var editMode

  @State var item: JellyfinLibraryItem

  @ScaledMetric var accessabilityScale: CGFloat = 1
  @State private var imageSize: CGSize = CGSize.zero

  var isSelected: Bool

  var body: some View {
    VStack {
      ZStack(alignment: .topTrailing) {
        JellyfinLibraryItemImageView(item: item)
          .background(
            GeometryReader { imageGeometry in
              Color.clear.onAppear {
                // we'd prever overlay to place the badge, but that's not available for us yet
                imageSize = imageGeometry.size
              }
            }
          )
          .overlay {
            if editMode?.wrappedValue.isEditing == true, item.kind == .audiobook {
              Image(systemName: isSelected ? "checkmark.circle" : "circle")
                .foregroundColor(.white)
                .background(isSelected ? .blue : .clear)
                .clipShape(Circle())
                .shadow(radius: 4.0)
                .font(.title2)
            }
          }
          .accessibilityHidden(true)

        switch item.kind {
        case .userView, .folder:
          folderBadge
        case .audiobook:
          EmptyView()
        }
      }

      Text(item.name)
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private var folderBadge: some View {
    let imageLength = min(imageSize.width, imageSize.height)
    ZStack {
      Circle().strokeBorder(.foreground, lineWidth: 1 * accessabilityScale)
        .background(Circle().fill(.background))
      Image(systemName: "folder.fill")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: imageLength * 0.1, height: imageLength * 0.1)
    }
    .frame(width: imageLength * 0.2, height: imageLength * 0.2, alignment: .topTrailing)
    .padding(5)
    .opacity(0.8)
  }
}
