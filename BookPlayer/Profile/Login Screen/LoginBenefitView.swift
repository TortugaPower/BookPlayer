//
//  LoginBenefitView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 20/7/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class LoginBenefitView: UIStackView, Themeable {
  private lazy var titleLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    label.font = Fonts.title
    return label
  }()

  private lazy var descriptionLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    label.font = Fonts.body
    return label
  }()

  private lazy var imageView: UIImageView = {
    let imageView = UIImageView()
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.contentMode = .scaleAspectFit

    return imageView
  }()

  private lazy var containerImageView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private lazy var imageOverlay: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.layer.masksToBounds = true
    view.layer.cornerRadius = 10
    view.alpha = 0.2
    return view
  }()

  let shouldAddOverlay: Bool

  init(
    title: String,
    description: String,
    shouldAddOverlay: Bool = false,
    imageName: String? = nil,
    systemName: String? = nil,
    imageAlpha: CGFloat = 1.0
  ) {
    self.shouldAddOverlay = shouldAddOverlay

    super.init(frame: .zero)

    axis = .horizontal

    titleLabel.text = title
    descriptionLabel.text = description

    if let imageName = imageName {
      imageView.image = UIImage(named: imageName)
    } else if let systemName = systemName {
      imageView.image = UIImage(systemName: systemName)
    }
    imageView.alpha = imageAlpha

    addSubviews()
    addConstraints()

    setUpTheming()
  }

  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func addSubviews() {
    let descriptionStackView = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel])
    descriptionStackView.axis = .vertical
    descriptionStackView.spacing = 10

    containerImageView.addSubview(imageView)
    containerImageView.addSubview(imageOverlay)

    if !shouldAddOverlay {
      imageOverlay.isHidden = true
    }

    let stackView = UIStackView(arrangedSubviews: [containerImageView, descriptionStackView])
    stackView.axis = .horizontal

    addArrangedSubview(stackView)
  }

  private func addConstraints() {
    NSLayoutConstraint.activate([
      containerImageView.widthAnchor.constraint(equalToConstant: 96),
      imageView.widthAnchor.constraint(equalToConstant: 50),
      imageView.heightAnchor.constraint(equalToConstant: 50),
      imageView.centerXAnchor.constraint(equalTo: containerImageView.centerXAnchor),
      imageView.centerYAnchor.constraint(equalTo: containerImageView.centerYAnchor),
      imageOverlay.topAnchor.constraint(equalTo: imageView.topAnchor),
      imageOverlay.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
      imageOverlay.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
      imageOverlay.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
    ])
  }

  func applyTheme(_ theme: SimpleTheme) {
    titleLabel.textColor = theme.primaryColor
    descriptionLabel.textColor = theme.secondaryColor
    imageView.tintColor = theme.linkColor
    imageOverlay.backgroundColor = theme.linkColor
  }
}
