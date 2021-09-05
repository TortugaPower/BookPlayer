//
//  NibLoadable.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit

class NibLoadable: UIView {
  var contentView: UIView?

  required init?(coder aDecoder: NSCoder) {
      super.init(coder: aDecoder)

      let view = loadViewFromNib()
      view.frame = self.bounds
      self.addSubview(view)
      self.contentView = view
  }

  func loadViewFromNib() -> UIView {
    let baseName = NSStringFromClass(type(of: self))
    let className = baseName.components(separatedBy: ".").last ?? baseName
    let nib = UINib(nibName: className, bundle: Bundle(for: type(of: self)))
    // swiftlint:disable force_cast
    return nib.instantiate(withOwner: self, options: nil).first as! UIView
  }
}
