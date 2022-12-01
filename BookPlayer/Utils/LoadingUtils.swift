//
//  LoadingUtils.swift
//  BookPlayer
//
//  Created by gianni.carlo on 16/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import UIKit

public class LoadingUtils {
  private static let loaderViewTag = 5959

  public class func createActivityIndicator(parentView: UIView) {
    let screenSize = UIScreen.main.bounds
    let backgroundView = UIView(frame: CGRect(
      x: screenSize.width / 2 - 30,
      y: screenSize.height / 2 - 30,
      width: 60,
      height: 60
    ))
    backgroundView.backgroundColor = .black.withAlpha(newAlpha: 0.8)
    backgroundView.layer.cornerRadius = 10

    let indicatorView = UIActivityIndicatorView(frame: CGRect(
      x: 0,
      y: 0,
      width: 60,
      height: 60
    ))
    indicatorView.color = .white
    indicatorView.hidesWhenStopped = true
    indicatorView.style = .medium
    backgroundView.addSubview(indicatorView)
    backgroundView.tag = loaderViewTag

    if let window = parentView.window {
      window.addSubview(backgroundView)
    } else {
      parentView.addSubview(backgroundView)
    }

    indicatorView.startAnimating()
  }

  public class func loadAndBlock(in vc: UIViewController) {
    vc.view.isUserInteractionEnabled = false
    vc.tabBarController?.tabBar.isUserInteractionEnabled = false
    Self.createActivityIndicator(parentView: vc.view)
  }

  public class func stopLoading(in vc: UIViewController) {
    vc.view.isUserInteractionEnabled = true
    vc.tabBarController?.tabBar.isUserInteractionEnabled = true

    for subview in vc.view.subviews where subview.tag == loaderViewTag {
      if let indicatorView = subview.subviews.first as? UIActivityIndicatorView {
        indicatorView.stopAnimating()
      }
      subview.removeFromSuperview()
    }
  }
}
