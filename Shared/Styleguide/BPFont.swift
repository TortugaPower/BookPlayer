//
//  BPFont.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

/// SwiftUI-native font system with automatic Dynamic Type support
public enum BPFont {
  // Standard text styles
  case headline
  case subheadline
  case body
  case caption
  case footnote

  // Title variants
  case title          // 16pt semibold (callout weight)
  case titleRegular   // 16pt regular
  case titleLarge     // 20pt semibold
  case title2         // 22pt regular

  // Story/onboarding
  case titleStory     // 24pt heavy (for story screens)
  case bodyStory      // 20pt regular

  // Pricing
  case pricingTitle   // Large heavy font for pricing

  // Small/caption variants
  case buttonTextSmall  // 11pt bold
  case captionMedium    // 13pt medium

  // Mini player
  case miniPlayerTitle   // 14pt semibold
  case miniPlayerAuthor  // 13pt regular

  // Special
  case iconLarge      // 48pt for large icons

  /// SwiftUI Font for iOS (uses native text styles for Dynamic Type)
  public var font: Font {
    switch self {
    case .headline:
      return .headline
    case .subheadline:
      return .subheadline
    case .body:
      return .body
    case .caption:
      return .caption
    case .footnote:
      return .footnote
    case .title:
      return .callout.weight(.semibold)
    case .titleRegular:
      return .callout
    case .titleLarge:
      return .title3.weight(.semibold)
    case .title2:
      return .title2
    case .titleStory:
      return .title2.weight(.heavy)
    case .bodyStory:
      return .title3
    case .pricingTitle:
      return .largeTitle.weight(.heavy)
    case .buttonTextSmall:
      return .caption2.weight(.bold)
    case .captionMedium:
      return .footnote.weight(.medium)
    case .miniPlayerTitle:
      return .subheadline.weight(.semibold)
    case .miniPlayerAuthor:
      return .footnote
    case .iconLarge:
      return .system(size: 48)
    }
  }

  /// Base point size for manual scaling (used on macOS)
  private var baseSize: CGFloat {
    switch self {
    case .headline: return 17
    case .subheadline: return 15
    case .body: return 17
    case .caption: return 12
    case .footnote: return 13
    case .title: return 16
    case .titleRegular: return 16
    case .titleLarge: return 20
    case .title2: return 22
    case .titleStory: return 22
    case .bodyStory: return 20
    case .pricingTitle: return 34
    case .buttonTextSmall: return 11
    case .captionMedium: return 13
    case .miniPlayerTitle: return 15
    case .miniPlayerAuthor: return 13
    case .iconLarge: return 48
    }
  }

  /// Font weight for manual scaling (used on macOS)
  private var fontWeight: Font.Weight {
    switch self {
    case .headline: return .semibold
    case .subheadline: return .regular
    case .body: return .regular
    case .caption: return .regular
    case .footnote: return .regular
    case .title: return .semibold
    case .titleRegular: return .regular
    case .titleLarge: return .semibold
    case .title2: return .regular
    case .titleStory: return .heavy
    case .bodyStory: return .regular
    case .pricingTitle: return .heavy
    case .buttonTextSmall: return .bold
    case .captionMedium: return .medium
    case .miniPlayerTitle: return .semibold
    case .miniPlayerAuthor: return .regular
    case .iconLarge: return .regular
    }
  }

  /// Returns a scaled font for macOS manual text scaling
  public func scaledFont(by factor: CGFloat) -> Font {
    .system(size: baseSize * factor, weight: fontWeight)
  }
}