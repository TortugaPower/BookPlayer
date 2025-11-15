//
//  AudiobookShelfLibraryGridItemView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Kingfisher
import SwiftUI

struct AudiobookShelfLibraryGridItemView: View {
  @Environment(\.editMode) private var editMode

  @State var item: AudiobookShelfLibraryItem

  @ScaledMetric var accessabilityScale: CGFloat = 1

  var isSelected: Bool

  var body: some View {
    VStack {
      ZStack(alignment: .topTrailing) {
        AudiobookShelfLibraryItemImageView(item: item)
          .overlay {
            if editMode?.wrappedValue.isEditing == true, item.kind == .audiobook {
              Image(systemName: isSelected ? "checkmark.circle" : "circle")
                .foregroundStyle(.white)
                .background(isSelected ? .blue : .clear)
                .clipShape(Circle())
                .shadow(radius: 4.0)
                .font(.title2)
            }
          }
          .accessibilityHidden(true)

        if item.kind == .library {
          libraryBadge
        }
      }

      Text(item.title)
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private var libraryBadge: some View {
    ZStack {
      Circle().strokeBorder(.foreground, lineWidth: 1 * accessabilityScale)
        .background(Circle().fill(.background))
      Image(systemName: "folder.fill")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .padding(4)
    }
    .frame(width: 32, height: 32)
    .padding(5)
    .opacity(0.8)
  }
}
