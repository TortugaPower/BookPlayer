//
//  ActionParserService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation
import Intents

class ActionParserService {
  public class func process(_ url: URL) {
    guard let action = CommandParser.parse(url) else { return }

    self.handleAction(action)
  }

  public class func process(_ activity: NSUserActivity) {
    guard let action = CommandParser.parse(activity) else { return }

    self.handleAction(action)
  }

  public class func process(_ intent: INIntent) {
    guard let action = CommandParser.parse(intent) else { return }

    self.handleAction(action)
  }

  public class func handleAction(_ action: Action) {
    guard let appDelegate = AppDelegate.shared else { return }

    appDelegate.pendingURLActions.append(action)

    guard
      let watchConnectivityService = appDelegate.watchConnectivityService,
      let playerManager = appDelegate.playerManager
    else { return }

    switch action.command {
    case .play:
      self.handlePlayAction(action)
    case .pause:
      self.handlePauseAction(action)
    case .download:
      self.handleDownloadAction(action)
    case .sleep:
      self.handleSleepAction(action)
    case .refresh:
      watchConnectivityService.sendApplicationContext()
      self.removeAction(action)
    case .skipRewind:
      playerManager.rewind()
    case .skipForward:
      playerManager.forward()
    case .widget:
      self.handleWidgetAction(action)
    case .fileImport:
      self.handleFileImportAction(action)
    case .boostVolume:
      self.handleBoostVolumeAction(action)
    case .speed:
      self.handleSpeedRateAction(action)
    case .chapter:
      self.handleChapterAction(action)
    }
  }

  private class func handleChapterAction(_ action: Action) {
    guard
      let valueString = action.getQueryValue(for: "start"),
      let chapterStart = Double(valueString),
      let playerManager = AppDelegate.shared?.playerManager
    else {
      return
    }

    playerManager.jumpTo(chapterStart + 0.05, recordBookmark: false)
  }

  private class func handleSpeedRateAction(_ action: Action) {
    guard
      let valueString = action.getQueryValue(for: "rate"),
      let speedRate = Float(valueString)
    else {
      return
    }

    let roundedValue = round(speedRate * 100) / 100.0

    guard
      let playerManager = AppDelegate.shared?.playerManager
    else {
      return
    }

    playerManager.setSpeed(roundedValue)
  }

  private class func handleBoostVolumeAction(_ action: Action) {
    guard let valueString = action.getQueryValue(for: "isOn") else { return }

    let isOn = valueString == "true"

    guard
      let playerManager = AppDelegate.shared?.playerManager
    else {
      return
    }

    UserDefaults.standard.set(
      isOn,
      forKey: Constants.UserDefaults.boostVolumeEnabled.rawValue
    )
    playerManager.setBoostVolume(isOn)
  }

  private class func handleFileImportAction(_ action: Action) {
    guard
      let libraryCoordinator = AppDelegate.shared?.activeSceneDelegate?.coordinator.getMainCoordinator()?.getLibraryCoordinator(),
      let urlString = action.getQueryValue(for: "url")
    else {
      return
    }

    let url = URL(fileURLWithPath: urlString)
    self.removeAction(action)
    libraryCoordinator.processFiles(urls: [url])
  }

  private class func handleSleepAction(_ action: Action) {
    guard let value = action.getQueryValue(for: "seconds"),
          let seconds = Double(value) else {
            return
          }

    switch seconds {
    case -1:
      SleepTimer.shared.reset()
    case -2:
      SleepTimer.shared.sleep(in: .endChapter)
    default:
      SleepTimer.shared.sleep(in: seconds)
    }
  }

  private class func handlePauseAction(_ action: Action) {
    guard
      let playerManager = AppDelegate.shared?.playerManager
    else {
      return
    }

    playerManager.pause(fade: false)
  }

  private class func handlePlayAction(_ action: Action) {
    guard
      let playerManager = AppDelegate.shared?.playerManager
    else {
      return
    }

    if let value = action.getQueryValue(for: "showPlayer"),
       let showPlayer = Bool(value),
       showPlayer {
      AppDelegate.shared?.showPlayer()
    }

    if let value = action.getQueryValue(for: "autoplay"),
       let autoplay = Bool(value),
       !autoplay {
      return
    }

    guard let bookIdentifier = action.getQueryValue(for: "identifier") else {
      self.removeAction(action)
      AppDelegate.shared?.playLastBook()
      return
    }

    if let loadedItem = playerManager.currentItem,
       loadedItem.relativePath == bookIdentifier {
      self.removeAction(action)
      playerManager.play()
      return
    }

    guard
      let libraryCoordinator = AppDelegate.shared?.activeSceneDelegate?.coordinator.getMainCoordinator()?.getLibraryCoordinator()
    else { return }

    self.removeAction(action)
    libraryCoordinator.loadPlayer(bookIdentifier)
  }

  private class func handleDownloadAction(_ action: Action) {
    guard
      let libraryCoordinator = AppDelegate.shared?.activeSceneDelegate?.coordinator.getMainCoordinator()?.getLibraryCoordinator(),
      let urlString = action.getQueryValue(for: "url")?.replacingOccurrences(of: "\"", with: "")
    else {
      return
    }

    guard let url = URL(string: urlString) else {
      libraryCoordinator.showAlert("error_title".localized, message: String.localizedStringWithFormat("invalid_url_title".localized, urlString))
      return
    }

    self.removeAction(action)
    libraryCoordinator.onAction?(.downloadBook(url))
  }

  private class func handleWidgetAction(_ action: Action) {
    if action.getQueryValue(for: "autoplay") != nil {
      let playAction = Action(command: .play, parameters: action.parameters)
      self.handleAction(playAction)
    }

    if action.getQueryValue(for: "seconds") != nil {
      let sleepAction = Action(command: .sleep, parameters: action.parameters)
      self.handleAction(sleepAction)
    }

    self.removeAction(action)
  }

  public class func removeAction(_ action: Action) {
    guard
      let appDelegate = AppDelegate.shared,
      let index = appDelegate.pendingURLActions.firstIndex(of: action)
    else {
      return
    }

    appDelegate.pendingURLActions.remove(at: index)
  }
}
