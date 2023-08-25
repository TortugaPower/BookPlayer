//
//  AccountProBenefitsView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 24/7/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit
import Themeable

class AccountProBenefitsView: UIStackView {
  private lazy var titleStackView: UIStackView = {
    let stackview = UIStackView(arrangedSubviews: [proLabel])
    stackview.axis = .horizontal
    return stackview
  }()
  
  private lazy var proLabel: UILabel = {
    let label = UILabel()
    label.text = "BookPlayer Pro"
    label.font = Fonts.title
    label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    return label
  }()
  
  private lazy var cloudBenefitView: UIView = {
    return AccountRowContainerView(
      title: "benefits_cloudsync_title".localized,
      systemImageName: "icloud.and.arrow.up.fill"
    )
  }()
  
  private lazy var cosmeticBenefitView: UIView = {
    return AccountRowContainerView(
      title: "benefits_themesicons_title".localized,
      shouldAddOverlay: true,
      imageName: "BookPlayerPlus",
      imageAlpha: 0.5
    )
  }()
  
  private lazy var supportBenefitView: UIView = {
    return AccountRowContainerView(
      title: "benefits_supportus_title".localized,
      imageName: "plusImageSupport"
    )
  }()
  
  private lazy var completeButton: UIButton = {
    let button = FormButton(title: "completeaccount_title".localized)
    button.addTarget(self, action: #selector(didTapButton), for: .touchUpInside)
    return button
  }()
  
  var tapAction: (() -> Void)?
  
  init() {
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = false
    axis = .vertical
    spacing = Spacing.S2
    
    addSubviews()
    setUpTheming()
  }
  
  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func addSubviews() {
    addArrangedSubview(titleStackView)
    addArrangedSubview(cloudBenefitView)
    addArrangedSubview(cosmeticBenefitView)
    addArrangedSubview(supportBenefitView)
    addArrangedSubview(completeButton)
  }
  
  @objc func didTapButton() {
    tapAction?()
  }
}

extension AccountProBenefitsView: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    proLabel.textColor = theme.primaryColor
  }
}
