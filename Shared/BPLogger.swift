//
//  BPLogger.swift
//  BookPlayer
//
//  Created by gianni.carlo on 10/7/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation
import os

public protocol BPLogger {}

extension BPLogger {
  public static var logger: Logger {
    return Logger(
      subsystem: Bundle.main.configurationString(for: .bundleIdentifier),
      category: String(describing: Self.self)
    )
  }
}
