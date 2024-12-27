//
//  BPAppShortcuts.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/9/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import Foundation
import AppIntents

@available(iOS 16.4, macOS 14.0, watchOS 10.0, *)
struct BPAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    return [
      AppShortcut(
        intent: LastBookStartPlaybackIntent(),
        phrases: [
          "Play the current book in \(.applicationName)",
          "Play the last book in \(.applicationName)",
          "Continue the last played book in \(.applicationName)"
        ],
        systemImageName: "play.fill"
      ),
      AppShortcut(
        intent: PausePlaybackIntent(),
        phrases: [
          "Pause the current book in \(.applicationName)",
          "Pause playback in \(.applicationName)",
          "Stop \(.applicationName)",
          "Stop playback in \(.applicationName)"
        ],
        systemImageName: "pause.fill"
      ),
      AppShortcut(
        intent: EndChapterSleepTimerIntent(),
        phrases: [
          "Set the sleep timer to the End of Chapter in \(.applicationName)",
          "Set the sleep timer to the End of the current Chapter in \(.applicationName)"
        ],
        systemImageName: "moon.fill"
      ),
      AppShortcut(
        intent: CancelSleepTimerIntent(),
        phrases: [
          "Cancel the sleep timer in \(.applicationName)",
          "Turn off the sleep timer in \(.applicationName)"
        ],
        systemImageName: "moon.fill"
      ),
      AppShortcut(
        intent: CustomSleepTimerIntent(),
        phrases: [
          "Set the sleep timer in \(.applicationName)",
          "Turn on the sleep timer in \(.applicationName)",
          "Enable the sleep timer in \(.applicationName)",
        ],
        systemImageName: "moon.fill"
      ),
      AppShortcut(
        intent: CustomRewindIntent(),
        phrases: [
          "Rewind in \(.applicationName)",
          "Jump back in \(.applicationName)",
          "Skip back in \(.applicationName)",
          "Go back in \(.applicationName)",
        ],
        systemImageName: "arrow.counterclockwise"
      ),
      AppShortcut(
        intent: CustomSkipForwardIntent(),
        phrases: [
          "Fast forward in \(.applicationName)",
          "Skip forward in \(.applicationName)",
          "Jump forward in \(.applicationName)",
        ],
        systemImageName: "arrow.clockwise"
      ),
    ]
  }

  static var shortcutTileColor: ShortcutTileColor = .navy
}
