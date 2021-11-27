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
import TelemetryClient

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
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

    appDelegate.coordinator.pendingURLActions.append(action)

    guard let mainCoordinator = appDelegate.coordinator.getMainCoordinator() else { return }

    switch action.command {
    case .play:
      self.handlePlayAction(action)
    case .download:
      self.handleDownloadAction(action)
    case .sleep:
      self.handleSleepAction(action)
    case .refresh:
      mainCoordinator.watchConnectivityService.sendApplicationContext()
      self.removeAction(action)
    case .skipRewind:
      mainCoordinator.playerManager.rewind()
    case .skipForward:
      mainCoordinator.playerManager.forward()
    case .widget:
      self.handleWidgetAction(action)
    case .fileImport:
      self.handleFileImportAction(action)
    }

    // avoid registering actions not (necessarily) initiated by the user
    if action.command != .refresh {
      TelemetryManager.shared.send(TelemetrySignal.urlSchemeAction.rawValue, with: action.getParametersDictionary())
    }
  }

  private class func handleFileImportAction(_ action: Action) {
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
          let libraryCoordinator = appDelegate.coordinator.getMainCoordinator()?.getLibraryCoordinator(),
          let urlString = action.getQueryValue(for: "url") else {
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

  private class func handlePlayAction(_ action: Action) {
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
          let mainCoordinator = appDelegate.coordinator.getMainCoordinator() else {
            return
          }

    if let value = action.getQueryValue(for: "showPlayer"),
       let showPlayer = Bool(value),
       showPlayer {
      appDelegate.showPlayer()
    }

    if let value = action.getQueryValue(for: "autoplay"),
       let autoplay = Bool(value),
       !autoplay {
      return
    }

    guard let bookIdentifier = action.getQueryValue(for: "identifier") else {
      self.removeAction(action)
      appDelegate.playLastBook()
      return
    }

    if let loadedBook = mainCoordinator.playerManager.currentBook,
       loadedBook.relativePath == bookIdentifier {
      self.removeAction(action)
      mainCoordinator.playerManager.play()
      return
    }

    guard let libraryCoordinator = mainCoordinator.getLibraryCoordinator() else { return }

    guard let book = libraryCoordinator.libraryService.getItem(with: bookIdentifier) as? Book else { return }

    self.removeAction(action)
    libraryCoordinator.loadPlayer(book)
  }

  private class func handleDownloadAction(_ action: Action) {
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
          let libraryCoordinator = appDelegate.coordinator.getMainCoordinator()?.getLibraryCoordinator(),
          let urlString = action.getQueryValue(for: "url")?.replacingOccurrences(of: "\"", with: "") else {
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
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
          let index = appDelegate.coordinator.pendingURLActions.firstIndex(of: action) else {
            return
          }

    appDelegate.coordinator.pendingURLActions.remove(at: index)
  }
}
