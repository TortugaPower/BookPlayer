//
//  BookPlaybackToggleIntent.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 21/11/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation
import AppIntents
import BookPlayerKit
import AVFoundation

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct BookPlaybackToggleIntent: AudioPlaybackIntent {

  static var title: LocalizedStringResource = .init("Toggle playback of book")

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
      playbackToggle: true
    ).absoluteString

    UserDefaults.sharedDefaults.set(
      url,
      forKey: Constants.UserDefaults.sharedWidgetActionURL
    )

    return .result()
  }
}
