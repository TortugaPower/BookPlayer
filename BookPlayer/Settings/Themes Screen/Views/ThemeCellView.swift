//
//  ThemeCellView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/18/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class ThemeCellView: UITableViewCell {
  @IBOutlet weak var showCaseView: UIView!
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var plusImageView: UIImageView!
  @IBOutlet weak var lockImageView: UIImageView!

  var isLocked: Bool = false {
    didSet {
      self.titleLabel.alpha = self.isLocked ? 0.5 : 1.0
      self.showCaseView.alpha = self.isLocked ? 0.5 : 1.0
      self.lockImageView.isHidden = !self.isLocked
    }
  }

  override func awakeFromNib() {
    super.awakeFromNib()

    self.showCaseView.layer.shadowColor = UIColor.black.cgColor
    self.showCaseView.layer.shadowOffset = CGSize(width: 0, height: 0)
    self.showCaseView.layer.shadowOpacity = 0.4
    self.showCaseView.layer.shadowRadius = 1.0

    setUpTheming()
  }

  func setupShowCaseView(for theme: SimpleTheme) {
    self.showCaseView.layer.sublayers = nil
    self.showCaseView.addLayerMask("themeColorBackgroundMask", backgroundColor: theme.lightSystemBackgroundColor)
    self.showCaseView.addLayerMask("themeColorAccentMask", backgroundColor: theme.lightLinkColor)
    self.showCaseView.addLayerMask("themeColorPrimaryMask", backgroundColor: theme.lightPrimaryColor)
    self.showCaseView.addLayerMask("themeColorSecondaryMask", backgroundColor: theme.lightSecondaryColor)
  }
}

extension ThemeCellView: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.titleLabel?.textColor = theme.primaryColor
    self.lockImageView.tintColor = theme.linkColor
    self.backgroundColor = theme.systemBackgroundColor
  }
}
