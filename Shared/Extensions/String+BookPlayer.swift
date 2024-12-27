//
//  String+BookPlayer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/11/20.
//  Copyright © 2020 BookPlayer LLC. All rights reserved.
//

import UIKit

extension String {
  public var localized: String {
    return NSLocalizedString(self, comment: "")
  }
}

extension String: LocalizedError {
  public var errorDescription: String? { return self }
}

extension String {
  /// There's a new `ranges(of:)` alternative in iOS 16
  public func allRanges(of string: String) -> [Range<String.Index>] {
    var ranges = [Range<String.Index>]()
    var searchStartIndex = self.startIndex

    while
      searchStartIndex < self.endIndex,
      let range = self.range(of: string, range: searchStartIndex..<self.endIndex),
      !range.isEmpty
    {
      ranges.append(range)
      searchStartIndex = range.upperBound
    }

    return ranges
  }
}
