//
//  ImportTableViewCell.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/6/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

final class ImportTableViewCell: UITableViewCell {
  @IBOutlet weak var deleteButton: UIButton!
  @IBOutlet weak var filenameLabel: UILabel!
  @IBOutlet weak var iconImageView: UIImageView!
  @IBOutlet weak var countLabel: UILabel!

  var onDeleteTap: (() -> Void)?

  override func awakeFromNib() {
    super.awakeFromNib()
    setUpTheming()
  }

  @IBAction func deleteTapped(_ sender: Any) {
      self.onDeleteTap?()
  }
}

extension ImportTableViewCell: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.filenameLabel?.textColor = theme.primaryColor
    self.iconImageView.tintColor = theme.linkColor
    self.countLabel?.textColor = theme.secondaryColor
    self.backgroundColor = theme.systemBackgroundColor
  }
}
