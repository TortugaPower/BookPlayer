//
//  BookmarkTableViewCell.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 6/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class BookmarkTableViewCell: UITableViewCell {
  @IBOutlet weak var timeLabel: UILabel!
  @IBOutlet weak var noteLabel: UILabel!
  @IBOutlet weak var iconImageView: UIImageView!

  override func awakeFromNib() {
    super.awakeFromNib()

    self.iconImageView.contentMode = .scaleAspectFill
    setUpTheming()
  }
}

extension BookmarkTableViewCell: Themeable {
  func applyTheme(_ theme: Theme) {
    self.timeLabel?.textColor = theme.secondaryColor
    self.noteLabel?.textColor = theme.primaryColor
    self.iconImageView.tintColor = theme.linkColor
    self.backgroundColor = theme.systemBackgroundColor
  }
}
