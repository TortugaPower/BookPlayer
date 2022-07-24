//
//  Fonts.swift
//  BookPlayer
//
//  Created by gianni.carlo on 23/7/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import UIKit

struct Fonts {
  static let title = UIFont.systemFont(ofSize: 16, weight: .semibold)
  static let titleRegular = UIFont.systemFont(ofSize: 16, weight: .regular)
  static let body = UIFont.systemFont(ofSize: 14, weight: .regular)
  /// Accessible fonts
  static let headline = UIFont(
    descriptor: UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline),
    size: 0.0
  )
}
