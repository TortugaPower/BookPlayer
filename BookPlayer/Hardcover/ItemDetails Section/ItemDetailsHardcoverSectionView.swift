//
//  ItemDetailsHardcoverSectionView.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/28/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import BookPlayerKit

struct ItemDetailsHardcoverSectionView: View {
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var theme: ThemeViewModel

  @ObservedObject var viewModel: ItemDetailsHardcoverSectionView.Model

  var body: some View {
    Section(
      header: HStack(spacing: Spacing.S) {
        Text("section_item_hardcover".localized)
          .foregroundStyle(theme.secondaryColor)
        if viewModel.isFetchingBook {
          ProgressView()
            .controlSize(.small)
        }
      }
    ) {
      NavigationLink(
        destination: {
          HardcoverBookPickerView(viewModel: viewModel.pickerViewModel)
        },
        label: {
          HardcoverSelectionLabel(pickerViewModel: viewModel.pickerViewModel)
        }
      )
      .accessibilityHint("voiceover_hardcover_navigation_hint".localized)
    }
    .listRowBackground(theme.secondarySystemBackgroundColor)
  }
}

/// Observes the picker view model directly so the row reflects `selected` as soon as it's
/// set — the section's own `@ObservedObject` won't fire for changes on the nested model.
private struct HardcoverSelectionLabel: View {
  @ObservedObject var pickerViewModel: HardcoverBookPickerView.Model

  var body: some View {
    if let row = pickerViewModel.selected {
      HardcoverBookRow(viewModel: row)
    } else {
      Text("select_title".localized)
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
    ItemDetailsHardcoverSectionView(viewModel: ItemDetailsHardcoverSectionView.Model())
  }
  .environmentObject(ThemeViewModel())
}
