//
//  UIFont+BookPlayer.swift
//  BookPlayer
//
//  Created by gianni.carlo on 24/7/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import UIKit

/// Reference: https://stackoverflow.com/a/62687023/2105150
extension UIFont {
  static func preferredFont(with size: CGFloat, style: TextStyle, weight: Weight, italic: Bool = false) -> UIFont {
    // Get the font at the specified size and preferred weight
    var font = UIFont.systemFont(ofSize: size, weight: weight)
    if italic == true {
      font = font.with([.traitItalic])
    }

    // Setup the font to be auto-scalable
    let metrics = UIFontMetrics(forTextStyle: style)
    return metrics.scaledFont(for: font)
  }

  private func with(_ traits: UIFontDescriptor.SymbolicTraits...) -> UIFont {
    guard let descriptor = fontDescriptor.withSymbolicTraits(UIFontDescriptor.SymbolicTraits(traits).union(fontDescriptor.symbolicTraits)) else {
      return self
    }
    return UIFont(descriptor: descriptor, size: 0)
  }
}
