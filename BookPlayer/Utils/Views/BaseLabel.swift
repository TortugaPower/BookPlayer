//
//  BaseLabel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 24/7/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import UIKit

/// Label wrapper for the setup of autolayout and font accessibility
class BaseLabel: UILabel {
  init() {
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = false
    adjustsFontForContentSizeCategory = true
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
