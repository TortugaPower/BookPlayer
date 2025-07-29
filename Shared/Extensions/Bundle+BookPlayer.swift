//
//  Bundle+BookPlayer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/17/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import Foundation

extension Bundle {
  /// Retrieve a configuration value from the receivers Info.plist dictionary
  public func configurationValue<T>(for key: String) throws -> T where T: LosslessStringConvertible {
    return try Configuration.value(for: key, bundle: self)
  }

  /// Retrieve a pre-defined configuration value from the receivers Info.plist dictionary. If the value does not exist the app will crash.
  public func configurationValue<T>(for key: ConfigurationKeys) -> T where T: LosslessStringConvertible {
    // swiftlint:disable force_try
    return try! configurationValue(for: key.rawValue)
    // swiftlint:enable force_try
  }

  public func configurationString(for key: ConfigurationKeys) -> String {
    let value: String = self.configurationValue(for: key)

    return value
  }
}
