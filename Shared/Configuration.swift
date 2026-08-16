//
//  Configuration.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/17/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import Foundation

public enum Configuration {
  enum Error: Swift.Error {
    case missingKey, invalidValue
  }

  static func value<T>(for key: String, bundle: Bundle = .main) throws -> T where T: LosslessStringConvertible {
    guard let object = bundle.object(forInfoDictionaryKey: key) else {
      throw Error.missingKey
    }

    switch object {
    case let value as T:
      return value
    case let string as String:
      guard let value = T(string) else { fallthrough }
      return value
    default:
      throw Error.invalidValue
    }
  }
}
