//
//  AccountRowContainerView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 24/7/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import UIKit
import Themeable

class AccountRowContainerView: UIView {
  private lazy var imageOverlay: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.isAccessibilityElement = false
    view.layer.masksToBounds = true
    view.layer.cornerRadius = 10
    view.alpha = 0.2
    return view
  }()

  private lazy var imageContainerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.isAccessibilityElement = false
    view.addSubview(imageView)
    view.addSubview(imageOverlay)
    return view
  }()

  private lazy var imageView: UIImageView = {
    let imageView = UIImageView(image: image)
    imageView.contentMode = .scaleAspectFit
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.isAccessibilityElement = false
    if flipImage {
      imageView.transform = imageView.transform.rotated(by: .pi / 2)
    }
    imageView.alpha = imageAlpha
    return imageView
  }()

  private lazy var titleLabel: UILabel = {
    let label = BaseLabel()
    label.setContentCompressionResistancePriority(.required, for: .horizontal)
    label.isAccessibilityElement = false
    return label
  }()

  private lazy var detailLabel: UILabel = {
    let label = BaseLabel()
    label.setContentHuggingPriority(.required, for: .horizontal)
    label.isAccessibilityElement = false
    return label
  }()

  private lazy var containerChevronView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.isAccessibilityElement = false
    view.addSubview(chevronImageView)
    return view
  }()

  private lazy var chevronImageView: UIImageView = {
    let imageView = UIImageView(image: UIImage(systemName: "chevron.forward"))
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.isAccessibilityElement = false
    imageView.contentMode = .scaleAspectFit
    return imageView
  }()

  private lazy var stackview: UIStackView = {
    let stackview = UIStackView(arrangedSubviews: [
      imageContainerView, titleLabel, detailLabel, containerChevronView
    ])
    stackview.translatesAutoresizingMaskIntoConstraints = false
    stackview.isAccessibilityElement = false
    stackview.distribution = .fillProportionally
    stackview.spacing = Spacing.S
    stackview.setCustomSpacing(Spacing.S2, after: detailLabel)
    return stackview
  }()

  /// Set default height to 44
  override var intrinsicContentSize: CGSize {
    return CGSize(width: frame.width, height: 44)
  }

  let showChevron: Bool
  let imageTintColor: UIColor?
  let shouldAddOverlay: Bool
  let imageAlpha: CGFloat
  let flipImage: Bool
  var image: UIImage?

  var tapAction: (() -> Void)?

  init(
    title: String,
    systemImageName: String? = nil,
    shouldAddOverlay: Bool = false,
    imageName: String? = nil,
    imageAlpha: CGFloat = 1.0,
    detail: String? = nil,
    showChevron: Bool = false,
    flipImage: Bool = false,
    imageTintColor: UIColor? = nil,
    titleFont: UIFont = Fonts.titleRegular,
    detailFont: UIFont = Fonts.titleRegular
  ) {
    self.showChevron = showChevron
    self.imageTintColor = imageTintColor
    self.shouldAddOverlay = shouldAddOverlay
    self.imageAlpha = imageAlpha
    self.flipImage = flipImage
    if let imageName = imageName {
      self.image = UIImage(named: imageName)
    } else if let systemImageName = systemImageName {
      self.image = UIImage(systemName: systemImageName)
    }
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = false
    titleLabel.text = title
    titleLabel.font = titleFont
    detailLabel.text = detail
    detailLabel.font = detailFont

    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    addGestureRecognizer(tapGesture)

    addSubviews()
    addConstraints()
    setUpTheming()

    isAccessibilityElement = true
    accessibilityTraits = [.button]
    var combinedAccessibilityLabel = title
    if let detail {
      combinedAccessibilityLabel += ", \(detail)"
    }
    accessibilityLabel = combinedAccessibilityLabel
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func addSubviews() {
    addSubview(stackview)

    if !shouldAddOverlay {
      imageOverlay.isHidden = true
    }
    if !showChevron {
      chevronImageView.isHidden = true
    }
  }

  func addConstraints() {
    NSLayoutConstraint.activate([
      stackview.leadingAnchor.constraint(equalTo: leadingAnchor),
      stackview.trailingAnchor.constraint(equalTo: trailingAnchor),
      stackview.topAnchor.constraint(equalTo: topAnchor),
      stackview.bottomAnchor.constraint(equalTo: bottomAnchor),
      imageContainerView.widthAnchor.constraint(equalToConstant: 25),
      imageView.widthAnchor.constraint(equalTo: imageContainerView.widthAnchor),
      imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
      imageView.centerYAnchor.constraint(equalTo: imageContainerView.centerYAnchor),
      imageView.centerXAnchor.constraint(equalTo: imageContainerView.centerXAnchor),
      containerChevronView.widthAnchor.constraint(equalToConstant: 15),
      chevronImageView.widthAnchor.constraint(equalTo: containerChevronView.widthAnchor),
      chevronImageView.heightAnchor.constraint(equalToConstant: 20),
      chevronImageView.centerYAnchor.constraint(equalTo: containerChevronView.centerYAnchor),
      imageOverlay.topAnchor.constraint(equalTo: imageView.topAnchor),
      imageOverlay.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
      imageOverlay.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
      imageOverlay.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
    ])
  }

  @objc func handleTap() {
    tapAction?()
  }
}

extension AccountRowContainerView: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    if let imageTintColor = imageTintColor {
      imageView.tintColor = imageTintColor
    } else {
      imageView.tintColor = theme.linkColor
    }

    titleLabel.textColor = theme.primaryColor
    detailLabel.textColor = theme.secondaryColor
    chevronImageView.tintColor = theme.secondaryColor
    imageOverlay.backgroundColor = theme.linkColor
  }
}
