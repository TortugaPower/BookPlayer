//
//  View+BookPlayer.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 9/12/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import SwiftUI

extension View {
  @ViewBuilder
  func customListSectionSpacing(_ spacing: CGFloat) -> some View {
    if #available(watchOS 10.0, *) {
      listSectionSpacing(spacing)
    } else {
      self
    }
  }

  @ViewBuilder
  func applyPrimaryHandGesture() -> some View {
    if #available(watchOS 11.0, *) {
      handGestureShortcut(.primaryAction)
    } else {
      self
    }
  }
}
