//
//  View+BookPlayer.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-11-10.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI

extension View {
  @ViewBuilder
  func defaultFormBackground() -> some View {
    if #available(iOS 16.0, *) {
      scrollContentBackground(.hidden)
    } else {
      self
    }
  }
}
