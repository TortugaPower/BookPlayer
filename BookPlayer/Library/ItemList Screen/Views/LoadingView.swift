//
//  LoadingView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/25/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class LoadingView: NibLoadableView {
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var subtitleLabel: UILabel!
  @IBOutlet weak var separatorView: UIView!
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    
    setUpTheming()
  }
}

extension LoadingView: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.backgroundColor = theme.tertiarySystemBackgroundColor
    self.titleLabel.textColor = theme.primaryColor
    self.subtitleLabel.textColor = theme.secondaryColor
    self.separatorView.backgroundColor = theme.separatorColor
    self.activityIndicator.color = theme.useDarkVariant ? .white : .gray
  }
}
