//
//  ItemDetailsHardcoverSectionView.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/28/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct ItemDetailsHardcoverSectionView: View {
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var theme: ThemeViewModel

  @ObservedObject var viewModel: ItemDetailsHardcoverSectionView.Model

  var body: some View {
    Section(
      header: Text("section_item_hardcover".localized)
        .foregroundStyle(theme.secondaryColor)
    ) {
      NavigationLink(
        destination: {
          HardcoverBookPickerView(viewModel: viewModel.pickerViewModel)
        },
        label: {
          if let row = viewModel.pickerViewModel.selected {
            HardcoverBookRow(viewModel: row)
          } else {
            Text("select_title".localized)
          }
        }
      )
      .accessibilityHint("voiceover_hardcover_navigation_hint".localized)
    }
  }
}

extension ItemDetailsHardcoverSectionView {
  class Model: ObservableObject {
    @Published var pickerViewModel: HardcoverBookPickerView.Model

    init(pickerViewModel: HardcoverBookPickerView.Model = .init()) {
      self.pickerViewModel = pickerViewModel
    }
  }
}

#Preview {
  Form {
    ItemDetailsHardcoverSectionView(viewModel: ItemDetailsHardcoverSectionView.Model())
  }
  .environmentObject(ThemeViewModel())
}
