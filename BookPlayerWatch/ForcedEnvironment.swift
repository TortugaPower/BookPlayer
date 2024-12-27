//
//  ForcedEnvironment.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 21/11/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import SwiftUI

@propertyWrapper
struct ForcedEnvironment<Value>: DynamicProperty {
  @Environment private var env: Value?

  init(_ keyPath: KeyPath<EnvironmentValues, Value?>) {
    _env = Environment(keyPath)
  }

  var wrappedValue: Value {
    if let env = env {
      return env
    } else {
      fatalError("\(Value.self) not provided")
    }
  }
}
