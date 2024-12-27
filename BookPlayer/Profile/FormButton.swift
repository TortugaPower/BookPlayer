//
//  FormButton.swift
//  BookPlayer
//
//  Created by gianni.carlo on 23/7/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import UIKit

class FormButton: UIButton {
  /// Set default height to 45
  override var intrinsicContentSize: CGSize {
    return CGSize(width: frame.width, height: 45)
  }

  init(
    title: String,
    cornerRadius: CGFloat = 6
  ) {
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = false
    clipsToBounds = true
    layer.cornerRadius = cornerRadius
    titleLabel?.font = Fonts.headline
    titleLabel?.adjustsFontForContentSizeCategory = true
    setTitle(title, for: .normal)
    backgroundColor = UIColor(hex: "687AB7")
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
