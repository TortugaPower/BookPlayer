//
//  ItemDetailsArtworkSectionView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 18/12/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ItemDetailsArtworkSectionView: View {
  /// Image to show in the section
  @Binding var image: UIImage?
  /// Callback for action handler
  var actionHandler: () -> Void
  /// Theme view model to update colors
  @EnvironmentObject var themeViewModel: ThemeViewModel

  var body: some View {
    Section(
      header: HStack {
        Text("artwork_title".localized)
          .foregroundColor(themeViewModel.secondaryColor)
        Spacer()
        Button(action: actionHandler) {
          if image != nil {
            Text("update_title".localized)
          } else {
            Text("library_add_button".localized)
          }
        }
        .foregroundColor(themeViewModel.linkColor)
      }
    ) {
      if let image = image {
        Image(uiImage: image)
          .resizable()
          .cornerRadius(4)
          .aspectRatio(contentMode: .fit)
      }
    }
  }
}

struct ItemDetailsArtworkSectionView_Previews: PreviewProvider {
  static var previews: some View {
    ItemDetailsArtworkSectionView(
      image: .constant(nil),
      actionHandler: {}
    )
    .environmentObject(ThemeViewModel())
  }
}
