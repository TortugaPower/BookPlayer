//
//  PricingModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 2/5/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import SwiftUI

public struct PricingModel: Identifiable, Equatable {
  public var id: String
  public let title: String

  public init(id: String, title: String) {
    self.id = id
    self.title = title
  }
}
