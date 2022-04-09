//
//  CompleteAccountViewController.swift
//  BookPlayer
//
//  Created by gianni.carlo on 8/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class CompleteAccountViewController: BaseViewController<CompleteAccountCoordinator, CompleteAccountViewModel>,
                                     Storyboarded {
  @IBOutlet weak var containerImageView: UIView!
  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var emailLabel: UILabel!
  @IBOutlet weak var proLabel: UILabel!
  @IBOutlet weak var costLabel: UILabel!
  @IBOutlet weak var monthlyLabel: UILabel!
  @IBOutlet weak var subscribeButton: UIButton!

  override func viewDidLoad() {
    super.viewDidLoad()

    self.title = "Complete Account"

    setUpTheming()

    self.setupViews()
  }

  func setupViews() {
    self.containerImageView.layer.masksToBounds = true
    self.containerImageView.layer.cornerRadius = self.containerImageView.frame.width / 2
    self.subscribeButton.layer.masksToBounds = true
    self.subscribeButton.layer.cornerRadius = 5
  }

  @IBAction func didPressClose(_ sender: UIBarButtonItem) {
    self.viewModel.dismiss()
  }
}

// MARK: - Themeable

extension CompleteAccountViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.view.backgroundColor = theme.systemBackgroundColor
    self.imageView.tintColor = theme.linkColor
    self.containerImageView.backgroundColor = theme.tertiarySystemBackgroundColor
    self.emailLabel.textColor = theme.primaryColor
    self.proLabel.textColor = theme.secondaryColor
    self.costLabel.textColor = theme.primaryColor
    self.monthlyLabel.textColor = theme.secondaryColor

    self.overrideUserInterfaceStyle = theme.useDarkVariant
      ? UIUserInterfaceStyle.dark
      : UIUserInterfaceStyle.light
  }
}
