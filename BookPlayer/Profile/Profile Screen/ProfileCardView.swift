//
//  ProfileCardView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 25/7/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit
import Themeable

class ProfileCardView: UIView {

  private lazy var containerStackView: UIStackView = {
    let stackview = UIStackView()
    stackview.translatesAutoresizingMaskIntoConstraints = false
    stackview.axis = .horizontal
    stackview.spacing = Spacing.S1
    return stackview
  }()

  private lazy var containerProfileImageView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.layer.masksToBounds = true
    view.layer.cornerRadius = containerProfileImageWidth / 2
    view.addSubview(profileImageView)
    return view
  }()

  private lazy var profileImageView: UIImageView = {
    let imageView = UIImageView(image: UIImage(systemName: "person"))
    imageView.translatesAutoresizingMaskIntoConstraints = false
    return imageView
  }()

  private lazy var labelsStackView: UIStackView = {
    let stackview = UIStackView()
    stackview.translatesAutoresizingMaskIntoConstraints = false
    stackview.axis = .vertical
    return stackview
  }()

  private lazy var titleLabel: UILabel = {
    let label = BaseLabel()
    label.font = Fonts.titleRegular
    return label
  }()

  private lazy var statusLabel: UILabel = {
    let label = BaseLabel()
    label.font = Fonts.subheadline
    return label
  }()

  private lazy var containerChevronView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(chevronImageView)
    return view
  }()

  private lazy var chevronImageView: UIImageView = {
    let imageView = UIImageView(image: UIImage(systemName: "chevron.right"))
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.contentMode = .scaleAspectFit
    imageView.image = imageView.image?.imageFlippedForRightToLeftLayoutDirection()
    return imageView
  }()

  /// Set default height to 70
  override var intrinsicContentSize: CGSize {
    return CGSize(width: frame.width, height: 70)
  }

  let containerProfileImageWidth: CGFloat
  let profileImageWidth: CGFloat
  let viewHeight: CGFloat = 70

  var tapAction: (() -> Void)?

  init(
    containerImageWidth: CGFloat = 40,
    imageWidth: CGFloat = 25,
    cornerRadius: CGFloat = 10
  ) {
    self.containerProfileImageWidth = containerImageWidth
    self.profileImageWidth = imageWidth

    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = false
    clipsToBounds = true
    layer.cornerRadius = cornerRadius

    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    addGestureRecognizer(tapGesture)

    addSubviews()
    addConstraints()
    setUpTheming()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func setup(title: String, status: String?) {
    titleLabel.text = title

    if let status = status {
      statusLabel.text = status
      statusLabel.isHidden = false
    } else {
      statusLabel.isHidden = true
    }
  }

  func addSubviews() {
    addSubview(containerStackView)
    containerStackView.addArrangedSubview(containerProfileImageView)
    labelsStackView.addArrangedSubview(statusLabel)
    labelsStackView.addArrangedSubview(titleLabel)
    containerStackView.addArrangedSubview(labelsStackView)
    containerStackView.addArrangedSubview(containerChevronView)
  }

  func addConstraints() {
    NSLayoutConstraint.activate([
      profileImageView.widthAnchor.constraint(equalToConstant: profileImageWidth),
      profileImageView.heightAnchor.constraint(equalTo: profileImageView.widthAnchor),
      profileImageView.centerXAnchor.constraint(equalTo: containerProfileImageView.centerXAnchor),
      profileImageView.centerYAnchor.constraint(equalTo: containerProfileImageView.centerYAnchor),
      containerProfileImageView.widthAnchor.constraint(equalToConstant: containerProfileImageWidth),
      containerProfileImageView.heightAnchor.constraint(equalTo: containerProfileImageView.widthAnchor),
      containerStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Spacing.S),
      containerStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Spacing.S),
      containerStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
      containerChevronView.widthAnchor.constraint(equalToConstant: 15),
      chevronImageView.widthAnchor.constraint(equalTo: containerChevronView.widthAnchor),
      chevronImageView.heightAnchor.constraint(equalToConstant: 20),
      chevronImageView.centerYAnchor.constraint(equalTo: containerChevronView.centerYAnchor),
    ])
  }

  @objc func handleTap() {
    tapAction?()
  }
}

extension ProfileCardView: Themeable {
  func applyTheme(_ theme: BookPlayerKit.SimpleTheme) {
    backgroundColor = theme.systemBackgroundColor
    titleLabel.textColor = theme.primaryColor
    statusLabel.textColor = theme.secondaryColor
    containerProfileImageView.backgroundColor = theme.tertiarySystemBackgroundColor
    profileImageView.tintColor = theme.secondaryColor
    chevronImageView.tintColor = theme.secondaryColor
  }
}
