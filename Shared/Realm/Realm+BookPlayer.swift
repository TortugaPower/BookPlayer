//
//  Realm+BookPlayer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 26/2/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import Foundation
import RealmSwift

extension Object {
  func toDictionaryPayload() -> [String: Any] {
    return objectSchema.properties.reduce(into: [:]) { dict, property in
      dict[property.name] = self.value(forKeyPath: property.name)
    }
  }
}
