//
//  AccountSectionContainerView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 24/7/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit
import Themeable

/// View simulating a table section with separators
class AccountSectionContainerView: UIView {
  let topSeparator = UIView()
  let contentView: UIView
  let insets: UIEdgeInsets
  let bottomSeparator = UIView()
  let separatorHeight: CGFloat = 0.67
  
  init(contents: UIView, insets: UIEdgeInsets, hideBottomSeparator: Bool = false) {
    self.contentView = contents
    self.insets = insets
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = false
    topSeparator.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    bottomSeparator.translatesAutoresizingMaskIntoConstraints = false
    bottomSeparator.isHidden = hideBottomSeparator
    
    addSubviews()
    addConstraints()
    setUpTheming()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func addSubviews() {
    addSubview(topSeparator)
    addSubview(contentView)
    addSubview(bottomSeparator)
  }
  
  func addConstraints() {
    NSLayoutConstraint.activate([
      topSeparator.topAnchor.constraint(equalTo: topAnchor),
      topSeparator.leadingAnchor.constraint(equalTo: leadingAnchor),
      topSeparator.trailingAnchor.constraint(equalTo: trailingAnchor),
      topSeparator.heightAnchor.constraint(equalToConstant: separatorHeight),
      contentView.topAnchor.constraint(equalTo: topSeparator.bottomAnchor, constant: insets.top),
      contentView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
      contentView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right),
      contentView.bottomAnchor.constraint(equalTo: bottomSeparator.topAnchor, constant: -insets.bottom),
      bottomSeparator.heightAnchor.constraint(equalToConstant: separatorHeight),
      bottomSeparator.leadingAnchor.constraint(equalTo: leadingAnchor),
      bottomSeparator.trailingAnchor.constraint(equalTo: trailingAnchor),
      bottomSeparator.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }
}

extension AccountSectionContainerView: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    topSeparator.backgroundColor = theme.separatorColor
    backgroundColor = theme.systemBackgroundColor
    bottomSeparator.backgroundColor = theme.separatorColor
  }
}
