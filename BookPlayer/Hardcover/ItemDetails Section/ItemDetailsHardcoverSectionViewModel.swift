//
//  ItemDetailsHardcoverSectionViewModel.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/28/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Get
import JellyfinAPI
import SwiftUI

final class ItemDetailsHardcoverSectionViewModel: ItemDetailsHardcoverSectionView.Model, BPLogger {
  private let service = HardcoverService()

  private var disposeBag = Set<AnyCancellable>()

  private let item: SimpleLibraryItem

  init?(item: SimpleLibraryItem) {
    guard service.authorization != nil else { return nil }

    self.item = item

    super.init(pickerViewModel: HardcoverBookPickerViewModel(item: item))
  }
}
