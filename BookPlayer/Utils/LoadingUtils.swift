//
//  LoadingUtils.swift
//  BookPlayer
//
//  Created by gianni.carlo on 16/4/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import UIKit

public class LoadingUtils {
  private static let loaderViewTag = 5959

  class func loaders(in vcToBlock: UIViewController) -> [UIView] {
    guard let window = vcToBlock.view.window else { return [] }
    return window.subviews.filter { $0.tag == loaderViewTag }
  }

  public class func createActivityIndicator(parentView: UIView) -> UIView {
    let container = parentView.window ?? parentView
    let backgroundView = UIView(frame: CGRect(
      x: container.bounds.midX - 30,
      y: container.bounds.midY - 30,
      width: 60,
      height: 60
    ))
    /// Centered on the window, not the screen: they differ in Split View and on iPhone Duo,
    /// and the flexible margins keep it centered when the window resizes (opening/closing Duo)
    backgroundView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
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

    container.addSubview(backgroundView)

    indicatorView.startAnimating()
    return backgroundView
  }

  public class func loadAndBlock(in vcToBlock: UIViewController) {
    guard let window = vcToBlock.view.window else { return }

    let hasHiddenLoader = !loaders(in: vcToBlock).isEmpty
    let loader = Self.createActivityIndicator(parentView: window)
    loader.isHidden = hasHiddenLoader

    window.isUserInteractionEnabled = false
  }

  public class func stopLoading(in vcToUnblock: UIViewController) {
    guard let window = vcToUnblock.view.window else { return }

    if let lastLoader = loaders(in: vcToUnblock).last {
      if let indicatorView = lastLoader.subviews.first as? UIActivityIndicatorView {
        indicatorView.stopAnimating()
      }
      lastLoader.removeFromSuperview()
    }

    window.isUserInteractionEnabled = loaders(in: vcToUnblock).isEmpty
  }
}
