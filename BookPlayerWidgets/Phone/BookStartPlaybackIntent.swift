//
//  BookStartPlaybackIntent.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 7/11/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation
import AppIntents
import BookPlayerKit
import AVFoundation

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct BookStartPlaybackIntent: AudioPlaybackIntent {

  static var title: LocalizedStringResource = .init("Start playback of book")

  @Parameter(title: "relativePath")
  var relativePath: String?

  init() {
    relativePath = nil
  }

  init(relativePath: String) {
    self.relativePath = relativePath
  }

  func perform() async throws -> some IntentResult {
    let url = WidgetUtils.getWidgetActionURL(
      with: relativePath,
      autoplay: true,
      timerSeconds: nil
    ).absoluteString

    let sharedDefaults = UserDefaults.sharedDefaults
    sharedDefaults.set(url, forKey: Constants.UserDefaults.sharedWidgetActionURL)

    return .result()
  }
}

