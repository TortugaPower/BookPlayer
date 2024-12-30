//
//  UIEdgeInsets+BookPlayer.swift
//  BookPlayer
//
//  Created by gianni.carlo on 4/12/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import UIKit

extension UIEdgeInsets {
  public init(horizontal x: CGFloat, vertical y: CGFloat) {
    self.init(top: y, left: x, bottom: y, right: x)
  }

  public init(all amount: CGFloat) {
    self.init(top: amount, left: amount, bottom: amount, right: amount)
  }
}
