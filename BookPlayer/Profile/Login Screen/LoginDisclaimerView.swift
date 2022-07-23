//
//  LoginDisclaimerView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 21/7/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class LoginDisclaimerView: UIStackView, Themeable {
  private lazy var titleLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
    return label
  }()

  private var disclaimerLabels = [UILabel]()

  init(
    title: String,
    disclaimers: [String]
  ) {
    super.init(frame: .zero)

    axis = .vertical
    spacing = 10

    titleLabel.text = title
    disclaimers.forEach { disclaimer in
      let label = UILabel()
      label.numberOfLines = 0
      label.text = disclaimer
      label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
      label.textAlignment = .justified
      disclaimerLabels.append(label)
    }

    addSubviews()
    setUpTheming()
  }

  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func addSubviews() {
    addArrangedSubview(titleLabel)
    disclaimerLabels.forEach { addArrangedSubview($0) }
  }

  func applyTheme(_ theme: SimpleTheme) {
    titleLabel.textColor = theme.primaryColor
    disclaimerLabels.forEach { $0.textColor = theme.secondaryColor }
  }
}
