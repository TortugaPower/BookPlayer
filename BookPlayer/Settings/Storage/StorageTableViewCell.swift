//
//  StorageTableViewCell.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 21/8/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class StorageTableViewCell: UITableViewCell {
  @IBOutlet weak var deleteButton: UIButton!
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var sizeLabel: UILabel!
  @IBOutlet weak var filenameLabel: UILabel!
  @IBOutlet weak var warningButton: UIButton!

  var onDeleteTap: (() -> Void)?
  var onWarningTap: (() -> Void)?

  override func awakeFromNib() {
    super.awakeFromNib()
    setUpTheming()
  }

  @IBAction func deleteTapped(_ sender: Any) {
      self.onDeleteTap?()
  }

  @IBAction func warningTapped(_ sender: Any) {
      self.onWarningTap?()
  }
}

extension StorageTableViewCell: Themeable {
  func applyTheme(_ theme: Theme) {
    self.titleLabel.textColor = theme.primaryColor
    self.filenameLabel?.textColor = theme.secondaryColor
    self.sizeLabel.textColor = theme.secondaryColor
    self.backgroundColor = theme.systemBackgroundColor
  }
}
