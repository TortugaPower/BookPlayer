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
  @ObservedObject var viewModel: ItemDetailsFormViewModel

  var body: some View {
    ItemDetailsForm(viewModel: viewModel)
      .defaultFormBackground()
  }
}

struct ItemDetailsView_Previews: PreviewProvider {
  static var previews: some View {
    ItemDetailsView(
      viewModel: ItemDetailsFormViewModel(
        item: SimpleLibraryItem(
          title: "title",
          details: "details",
          speed: 1,
          currentTime: 0,
          duration: 100,
          percentCompleted: 1,
          isFinished: false,
          relativePath: "",
          remoteURL: nil,
          artworkURL: nil,
          orderRank: 0,
          parentFolder: nil,
          originalFileName: "",
          lastPlayDate: nil,
          type: .book
        )
      )
    )
  }
}
