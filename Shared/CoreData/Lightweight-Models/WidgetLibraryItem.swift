//
//  WidgetLibraryItem.swift
//  BookPlayerWidgetsPhone
//
//  Created by Gianni Carlo on 30/9/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation

public struct WidgetLibraryItem: Codable {
  public let relativePath: String
  public let title: String
  public let details: String?

  public init(
    relativePath: String,
    title: String,
    details: String? = nil
  ) {
    self.relativePath = relativePath
    self.title = title
    self.details = details
  }
}
