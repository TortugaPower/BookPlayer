//
//  Binding+BookPlayer.swift
//  BookPlayer
//
//  Created by gianni.carlo on 4/7/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import SwiftUI

extension Binding {
  func isNotNil<T>() -> Binding<Bool> where Value == T? {
    .init(get: {
      wrappedValue != nil
    }, set: { _ in
      wrappedValue = nil
    })
  }
}
