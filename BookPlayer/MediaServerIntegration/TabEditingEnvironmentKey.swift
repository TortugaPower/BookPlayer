//
//  TabEditingEnvironmentKey.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

private struct TabEditingKey: EnvironmentKey {
  static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
  var tabEditing: Binding<Bool> {
    get { self[TabEditingKey.self] }
    set { self[TabEditingKey.self] = newValue }
  }
}
