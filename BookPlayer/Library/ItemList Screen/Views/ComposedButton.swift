//
//  ComposedButton.swift
//  BookPlayer
//
//  Created by gianni.carlo on 21/10/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class ComposedButton: UIButton {
  var title: String
  let font: UIFont
  let secondaryTitle: String?
  let systemImage: String?
  let imageHeight: CGFloat?
  var theme: SimpleTheme?
  
  init(
    title: String,
    secondaryTitle: String? = nil,
    systemImage: String? = nil,
    imageHeight: CGFloat? = nil,
    font: UIFont = Fonts.titleRegular
  ) {
    self.title = title
    self.secondaryTitle = secondaryTitle
    self.systemImage = systemImage
    self.imageHeight = imageHeight
    self.font = font
    
    super.init(frame: .zero)
    titleLabel?.lineBreakMode = .byClipping
    titleLabel?.adjustsFontForContentSizeCategory = true
    self.setUpTheming()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func setTitle(_ title: String?, for state: UIControl.State) {
    self.title = title ?? ""
    applyTitle()
  }
  
  func applyTitle() {
    guard let theme else { return }
    
    let fullString = NSMutableAttributedString(
      string: title,
      attributes: [.font: font, .foregroundColor: theme.linkColor]
    )
    let highlightedString = NSMutableAttributedString(
      string: title,
      attributes: [.font: font, .foregroundColor: theme.linkColor.withAlphaComponent(0.5)]
    )
    
    if let secondaryTitle {
      fullString.insert(
        NSAttributedString(
          string: "\(secondaryTitle) ",
          attributes: [.font: font, .foregroundColor: theme.secondaryColor]
        ),
        at: 0
      )
      highlightedString.insert(
        NSAttributedString(
          string: "\(secondaryTitle) ",
          attributes: [.font: font, .foregroundColor: theme.secondaryColor.withAlphaComponent(0.5)]
        ),
        at: 0
      )
    }
    
    if let systemImage,
       let imageHeight,
       let image = UIImage(systemName: systemImage) {
      let imageAttachment = NSTextAttachment()
      imageAttachment.image = image.withTintColor(theme.linkColor)
      let ratio = image.size.width / image.size.height
      let bounds = imageAttachment.bounds
      imageAttachment.bounds = CGRect(
        x: bounds.origin.x,
        y: bounds.origin.y,
        width: ratio * imageHeight,
        height: imageHeight
      )
      fullString.append(NSAttributedString(string: " "))
      fullString.append(NSAttributedString(attachment: imageAttachment))
      highlightedString.append(NSAttributedString(string: " "))
      highlightedString.append(NSAttributedString(attachment: imageAttachment))
    }
    
    setAttributedTitle(fullString, for: .normal)
    setAttributedTitle(highlightedString, for: .highlighted)
  }
}

extension ComposedButton: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.theme = theme
    self.applyTitle()
  }
}
