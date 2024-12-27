//
//  Realm+BookPlayer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 26/2/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation
import RealmSwift

extension Object {
  func toDictionaryPayload() -> [String: Any] {
    return objectSchema.properties.reduce(into: [:]) { dict, property in
      var value = self.value(forKeyPath: property.name)

      /// Sanitize infinite values
      if let doubleValue = value as? Double,
         !doubleValue.isFinite {
        switch property.name {
        case "speed", "lastPlayDateTimestamp":
          value = nil
        case "currentTime", "duration", "percentCompleted":
          value = 0.0
        default:
          break
        }
      }

      dict[property.name] = value
    }
  }
}
