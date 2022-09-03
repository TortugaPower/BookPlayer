//
//  GestureItemRow.swift
//  BookPlayer
//
//  Created by gianni.carlo on 2/9/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit
import Themeable

class GestureItemRow: UIStackView {
  private lazy var imageView: UIImageView = {
    let imageView = UIImageView()
    imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    return imageView
  }()

  private lazy var titleLabel: UILabel = {
    let label = UILabel()
    label.setContentCompressionResistancePriority(.required, for: .horizontal)
    label.numberOfLines = 0
    return label
  }()

  init(
    title: String,
    systemImageName: String
  ) {
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = false
    imageView.image = UIImage(systemName: systemImageName)
    titleLabel.text = title
    titleLabel.font = UIFont.preferredFont(with: 16, style: .body, weight: .regular)
    axis = .horizontal
    spacing = 8
    addSubviews()
    setUpTheming()
  }

  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func addSubviews() {
    addArrangedSubview(imageView)
    addArrangedSubview(titleLabel)
  }
}

extension GestureItemRow: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    imageView.tintColor = theme.secondaryColor
    titleLabel.textColor = theme.primaryColor
  }
}
