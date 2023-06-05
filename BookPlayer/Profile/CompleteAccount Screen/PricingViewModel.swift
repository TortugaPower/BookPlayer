//
//  PricingViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 3/5/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation

class PricingViewModel: ObservableObject {
  @Published var options: [PricingModel] = []
  @Published var selected: PricingModel?
  @Published var isLoading: Bool = true

  convenience init(options: [PricingModel]) {
    self.init()
    self.options = options
    self.selected = options.first
  }
}
