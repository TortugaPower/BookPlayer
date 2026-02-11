//
//  ItemDetailsArtworkSectionView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 18/12/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ItemDetailsArtworkSectionView: View {
  /// Image to show in the section
  @Binding var image: UIImage?
  /// Callback for action handler
  var actionHandler: () -> Void
  /// Theme view model to update colors
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    ThemedSection {
      HStack {
        if let image = image {
          Image(uiImage: image)
            .resizable()
            .cornerRadius(4)
            .aspectRatio(contentMode: .fit)
            .frame(width: 100, height: 100)
        } else if let defaultArtwork = theme.defaultArtwork {
          defaultArtwork
            .resizable()
            .cornerRadius(4)
            .aspectRatio(contentMode: .fit)
            .frame(width: 100, height: 100)
        }
        Spacer()

        Button(
          "update_title",
          systemImage: "plus",
          action: actionHandler
        )
        .labelStyle(.vertical)
        .buttonStyle(.plain)
        .imageScale(.large)
        .foregroundStyle(theme.linkColor)
        Spacer()
        Spacer()
          .frame(width: 0.5, height: 45)
          .background(theme.secondaryColor.opacity(0.5))
        Spacer()
        Button("delete_button", systemImage: "trash", role: .destructive) {
          image = ImageRenderer(content: theme.defaultArtwork).uiImage
        }
        .labelStyle(.vertical)
        .buttonStyle(.plain)
        .imageScale(.large)
        .foregroundStyle(.red)
        Spacer()
      }
    } header: {
      Text("artwork_title")
        .foregroundStyle(theme.secondaryColor)
    }
    .listRowBackground(theme.secondarySystemBackgroundColor)
  }
}

#Preview {
  @Previewable var artwork: UIImage?

  Form {
    ItemDetailsArtworkSectionView(image: .constant(artwork)) {
      print("Action")
    }
  }
  .environmentObject(ThemeViewModel())
}
