//
//  ItemDetailsView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 18/12/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ItemDetailsView: View {
  @ObservedObject var viewModel: ItemDetailsFormViewModel

  var body: some View {
    if #available(iOS 16.0, *) {
      ItemDetailsForm(viewModel: viewModel)
      .scrollContentBackground(.hidden)
    } else {
      ItemDetailsForm(viewModel: viewModel)
    }
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
