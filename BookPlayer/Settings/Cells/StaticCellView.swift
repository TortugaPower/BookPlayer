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

    let titleDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
    let font = UIFont(descriptor: titleDescriptor, size: 0.0)
    self.customLabel?.font = font
    self.customLabel?.adjustsFontForContentSizeCategory = true
    self.textLabel?.font = font
    self.textLabel?.adjustsFontForContentSizeCategory = true

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
