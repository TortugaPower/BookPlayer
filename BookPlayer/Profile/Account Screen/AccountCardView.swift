//
//  AccountCardView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 24/7/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit
import Themeable

class AccountCardView: UIView {
  private lazy var containerProfileImageView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.isAccessibilityElement = false
    view.layer.masksToBounds = true
    view.layer.cornerRadius = containerProfileImageWidth / 2
    return view
  }()
  
  private lazy var profileImageView: UIImageView = {
    let imageView = UIImageView(image: UIImage(systemName: "person"))
    imageView.isAccessibilityElement = false
    imageView.translatesAutoresizingMaskIntoConstraints = false
    return imageView
  }()
  
  private lazy var accountLabel: UILabel = {
    let label = BaseLabel()
    label.isAccessibilityElement = false
    label.text = title
    label.font = Fonts.titleRegular
    return label
  }()
  
  /// Set default height to 70
  override var intrinsicContentSize: CGSize {
    return CGSize(width: frame.width, height: 70)
  }
  
  let title: String?
  let containerProfileImageWidth: CGFloat
  let profileImageWidth: CGFloat
  let viewHeight: CGFloat = 70
  
  init(
    title: String?,
    containerImageWidth: CGFloat = 40,
    imageWidth: CGFloat = 25,
    cornerRadius: CGFloat = 10
  ) {
    self.title = title
    self.containerProfileImageWidth = containerImageWidth
    self.profileImageWidth = imageWidth
    
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = false
    clipsToBounds = true
    layer.cornerRadius = cornerRadius
    
    addSubviews()
    addConstraints()
    setUpTheming()
    
    isAccessibilityElement = true
    accessibilityLabel = title
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func addSubviews() {
    containerProfileImageView.addSubview(profileImageView)
    addSubview(containerProfileImageView)
    addSubview(accountLabel)
  }
  
  func addConstraints() {
    NSLayoutConstraint.activate([
      profileImageView.widthAnchor.constraint(equalToConstant: profileImageWidth),
      profileImageView.heightAnchor.constraint(equalTo: profileImageView.widthAnchor),
      profileImageView.centerXAnchor.constraint(equalTo: containerProfileImageView.centerXAnchor),
      profileImageView.centerYAnchor.constraint(equalTo: containerProfileImageView.centerYAnchor),
      containerProfileImageView.widthAnchor.constraint(equalToConstant: containerProfileImageWidth),
      containerProfileImageView.heightAnchor.constraint(equalTo: containerProfileImageView.widthAnchor),
      containerProfileImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Spacing.S),
      containerProfileImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
      accountLabel.leadingAnchor.constraint(equalTo: containerProfileImageView.trailingAnchor, constant: Spacing.S1),
      accountLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Spacing.S),
      accountLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
  }
}

extension AccountCardView: Themeable {
  func applyTheme(_ theme: BookPlayerKit.SimpleTheme) {
    backgroundColor = theme.secondarySystemBackgroundColor
    accountLabel.textColor = theme.primaryColor
    containerProfileImageView.backgroundColor = theme.tertiarySystemBackgroundColor
    profileImageView.tintColor = theme.secondaryColor
  }
}
