//
//  AddCellView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/21/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class AddCellView: UITableViewCell {
  @IBOutlet weak var addImageView: UIImageView!
  @IBOutlet weak var titleLabel: UILabel!
  
  override func awakeFromNib() {
    super.awakeFromNib()
    self.titleLabel.accessibilityLabel = "playlist_add_title".localized
    let titleDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
    self.titleLabel.font = UIFont(descriptor: titleDescriptor, size: 0.0)
    self.titleLabel.adjustsFontForContentSizeCategory = true
    setUpTheming()
  }
}

extension AddCellView: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.titleLabel.textColor = theme.linkColor
    self.backgroundColor = theme.systemBackgroundColor
    self.addImageView.tintColor = theme.linkColor
  }
}
