//
//  AccessibleSliderView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 28/1/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import UIKit

class AccessibleSliderView: UISlider {
  var intervalValue: Float = 0.1

  override class func isAccessibilityElement() -> Bool {
    return true
  }

  override class func accessibilityTraits() -> UIAccessibilityTraits {
    return .adjustable
  }

  override func accessibilityDecrement() {
    self.value -= self.intervalValue
    self.accessibilityValue = "\(round(self.value * 100) / 100.0)"
  }

  override func accessibilityIncrement() {
    self.value += self.intervalValue
    self.accessibilityValue = "\(round(self.value * 100) / 100.0)"
  }
}
