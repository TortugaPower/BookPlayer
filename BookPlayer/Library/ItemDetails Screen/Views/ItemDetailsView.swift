//
//  ItemDetailsView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 18/12/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ItemDetailsView: View {
  @ObservedObject var viewModel: ItemDetailsForm.Model

  var body: some View {
    ItemDetailsForm(viewModel: viewModel)
      .defaultFormBackground()
  }
}

struct ItemDetailsView_Previews: PreviewProvider {
  static var previews: some View {
    ItemDetailsView(
      viewModel: ItemDetailsForm.Model(
        originalFileName: "this is a test filename.mp3",
        title: "title",
        author: "author",
        selectedImage: nil,
        progress: 0.01,
        lastPlayedDate: nil,
        titlePlaceholder: "",
        authorPlaceholder: "",
        showAuthor: true
      )
    )
  }
}
