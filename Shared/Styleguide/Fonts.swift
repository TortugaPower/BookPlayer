//
//  Fonts.swift
//  BookPlayer
//
//  Created by gianni.carlo on 23/7/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import UIKit

public struct Fonts {
  public static let title = UIFont.preferredFont(with: 16, style: .headline, weight: .semibold)
  public static let titleRegular = UIFont.preferredFont(with: 16, style: .headline, weight: .regular)
  public static let titleLarge = UIFont.preferredFont(with: 20, style: .largeTitle, weight: .semibold)
  public static let body = UIFont.preferredFont(with: 14, style: .body, weight: .regular)
  public static let headline = UIFont.preferredFont(forTextStyle: .headline)
  public static let subheadline = UIFont.preferredFont(forTextStyle: .subheadline)

  public static let titleStory = UIFont.preferredFont(with: 24, style: .largeTitle, weight: .heavy)
  public static let bodyStory = UIFont.preferredFont(with: 20, style: .title1, weight: .regular)

  public static let pricingTitle = UIFont.preferredFont(with: 40, style: .largeTitle, weight: .heavy)
}
