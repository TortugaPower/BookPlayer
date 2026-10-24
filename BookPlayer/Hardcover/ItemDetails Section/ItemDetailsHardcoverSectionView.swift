//
//  ItemDetailsHardcoverSectionView.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/28/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import BookPlayerKit

/// The Hardcover row of an item's Integrations section (`ItemDetailsIntegrationsSectionView`):
/// the linked book, or Select, opening the picker.
struct ItemDetailsHardcoverSectionView: View {
  @ObservedObject var viewModel: ItemDetailsHardcoverSectionView.Model

  var body: some View {
    NavigationLink(
      destination: {
        HardcoverBookPickerView(viewModel: viewModel.pickerViewModel)
      },
      label: {
        HardcoverSelectionLabel(
          pickerViewModel: viewModel.pickerViewModel,
          isFetchingBook: viewModel.isFetchingBook
        )
      }
    )
    .accessibilityHint("voiceover_hardcover_navigation_hint".localized)
  }
}

/// Observes the picker view model directly so the row reflects `selected` as soon as it's
/// set — the row's own `@ObservedObject` won't fire for changes on the nested model.
private struct HardcoverSelectionLabel: View {
  @ObservedObject var pickerViewModel: HardcoverBookPickerView.Model
  let isFetchingBook: Bool

  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    if let row = pickerViewModel.selected {
      VStack(alignment: .leading, spacing: Spacing.S1) {
        Text("section_item_hardcover")
          .bpFont(.caption)
          .foregroundStyle(theme.secondaryColor)
        HardcoverBookRow(viewModel: row)
      }
    } else {
      HStack {
        Text("section_item_hardcover")
          .foregroundStyle(theme.primaryColor)
        Spacer()
        if isFetchingBook {
          ProgressView()
            .controlSize(.small)
        } else {
          Text("select_title")
            .foregroundStyle(theme.secondaryColor)
        }
      }
    }
  }
}

extension ItemDetailsHardcoverSectionView {
  class Model: ObservableObject {
    @Published var pickerViewModel: HardcoverBookPickerView.Model
    /// True while fetching the linked book's info from Hardcover via its external resource
    @Published var isFetchingBook: Bool = false

    init(pickerViewModel: HardcoverBookPickerView.Model = .init()) {
      self.pickerViewModel = pickerViewModel
    }
  }
}

#Preview {
  Form {
    Section {
      ItemDetailsHardcoverSectionView(viewModel: ItemDetailsHardcoverSectionView.Model())
    }
  }
  .environmentObject(ThemeViewModel())
}
