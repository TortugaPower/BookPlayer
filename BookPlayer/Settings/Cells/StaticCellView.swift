//
//  StaticCellView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/21/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class StaticCellView: UITableViewCell {
  @IBOutlet weak var customLabel: UILabel?

  override func awakeFromNib() {
    super.awakeFromNib()

    let font = UIFont.preferredFont(forTextStyle: .body)
    self.customLabel?.font = font
    self.customLabel?.adjustsFontForContentSizeCategory = true
    self.textLabel?.font = font
    self.textLabel?.adjustsFontForContentSizeCategory = true
    self.detailTextLabel?.font = font
    self.detailTextLabel?.adjustsFontForContentSizeCategory = true

    setUpTheming()
  }
}

extension StaticCellView: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.textLabel?.textColor = theme.primaryColor
    self.customLabel?.textColor = theme.primaryColor
    self.detailTextLabel?.textColor = theme.secondaryColor
    self.backgroundColor = theme.systemBackgroundColor
  }
}
