//
//  ThemedTableViewCell.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 18/11/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class ThemedTableViewCell: UITableViewCell {
  override func awakeFromNib() {
    super.awakeFromNib()
    setUpTheming()
  }
}

extension ThemedTableViewCell: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.textLabel?.textColor = theme.primaryColor
    self.detailTextLabel?.textColor = theme.secondaryColor
    self.backgroundColor = theme.systemBackgroundColor
  }
}
