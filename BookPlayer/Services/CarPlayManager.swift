//
//  CarPlayManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 8/12/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import CarPlay

class CarPlayManager: NSObject {
  var interfaceController: CPInterfaceController?
  let mainCoordinator: MainCoordinator
  var recentItems = [PlayableItem]()

  private var disposeBag = Set<AnyCancellable>()
  /// Reference for updating boost volume title
  let boostVolumeItem = CPListItem(text: "", detailText: nil)
  /// Refresh flag in case the root template is not visible
  var needsReload = false

  override init() {
    self.mainCoordinator = SceneDelegate.shared!.coordinator.getMainCoordinator()!

    super.init()

    self.bindObservers()
  }

  // MARK: - Lifecycle

  func connect(_ interfaceController: CPInterfaceController) {
    self.interfaceController = interfaceController
    self.interfaceController?.delegate = self
    self.loadRecentItems()
    self.setupNowPlayingTemplate()
    self.setRootTemplateRecentItems()
  }

  func disconnect() {
    self.interfaceController = nil
    self.needsReload = false
  }

  func bindObservers() {
    NotificationCenter.default.publisher(for: .bookReady, object: nil)
      .sink(receiveValue: { [weak self] notification in
        guard
          let self = self,
          let loaded = notification.userInfo?["loaded"] as? Bool,
          loaded == true
        else {
          return
        }

        if self.interfaceController?.topTemplate == self.interfaceController?.rootTemplate {
          self.loadRecentItems()
          self.setRootTemplateRecentItems()
          self.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
        } else {
          self.needsReload = true
        }

        self.setupNowPlayingTemplate()
      })
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .chapterChange, object: nil)
      .delay(for: .seconds(0.1), scheduler: RunLoop.main, options: .none)
      .sink(receiveValue: { [weak self] _ in
        self?.setupNowPlayingTemplate()
      })
      .store(in: &disposeBag)

    self.boostVolumeItem.handler = { [weak self] (_, completion) in
      let flag = UserDefaults.standard.bool(forKey: Constants.UserDefaults.boostVolumeEnabled.rawValue)

      NotificationCenter.default.post(
        name: .messageReceived,
        object: self,
        userInfo: [
          "command": Command.boostVolume.rawValue,
          "isOn": "\(!flag)"
        ]
      )

      let boostTitle = !flag
      ? "\("settings_boostvolume_title".localized): \("active_title".localized)"
      : "\("settings_boostvolume_title".localized): \("sleep_off_title".localized)"

      self?.boostVolumeItem.setText(boostTitle)
      completion()
    }
  }

  func loadRecentItems() {
    if let recentBooks = mainCoordinator.libraryService.getLastPlayedItems(limit: 20) {
      recentItems = recentBooks.compactMap({ try? mainCoordinator.playbackService.getPlayableItem(from: $0) })
    }
  }

  func setupNowPlayingTemplate() {
    let prevButton = self.getPreviousChapterButton()

    let nextButton = self.getNextChapterButton()

    let controlsButton = CPNowPlayingPlaybackRateButton { [weak self] _ in
      self?.showPlaybackControlsTemplate()
    }

    let chaptersButton = CPNowPlayingImageButton(image: UIImage(systemName: "list.bullet")!) { [weak self] _ in
      self?.showChapterListTemplate()
    }

    let bookmarksButton = CPNowPlayingImageButton(image: UIImage(named: "toolbarIconBookmark")!) { [weak self] _ in
      guard
        let self = self,
        let currentItem = self.mainCoordinator.playerManager.currentItem
      else { return }

      let bookmark = self.mainCoordinator.libraryService.createBookmark(
        at: currentItem.currentTime,
        relativePath: currentItem.relativePath,
        type: .user
      )

      let formattedTime = TimeParser.formatTime(bookmark.time)

      let alertTitle = String.localizedStringWithFormat("bookmark_created_title".localized, formattedTime)
      let okAction = CPAlertAction(title: "ok_button".localized, style: .default) { _ in
        self.interfaceController?.dismissTemplate(animated: true, completion: nil)
      }
      let alertTemplate = CPAlertTemplate(titleVariants: [alertTitle], actions: [okAction])

      self.interfaceController?.presentTemplate(alertTemplate, animated: true, completion: nil)
    }

    CPNowPlayingTemplate.shared.updateNowPlayingButtons([prevButton, controlsButton, bookmarksButton, chaptersButton, nextButton])
  }

  func handleItemSelection(_ item: CPSelectableListItem) {
    if let listTemplate = self.interfaceController?.rootTemplate as? CPListTemplate,
       let indexPath = listTemplate.indexPath(for: item) {
      let selectedItem = recentItems[indexPath.row]
      NotificationCenter.default.post(
        name: .messageReceived,
        object: self,
        userInfo: [
          "command": Command.play.rawValue,
          "identifier": selectedItem.relativePath
        ]
      )
    }
    self.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
  }

  func setRootTemplateRecentItems() {
    let items = self.recentItems.map({ playableItem -> CPListItem in
      let item = CPListItem(
        text: playableItem.title,
        detailText: playableItem.author,
        image: UIImage(contentsOfFile: ArtworkService.getCachedImageURL(for: playableItem.relativePath).path)
      )
      item.playbackProgress = CGFloat(playableItem.progressPercentage)
      item.handler = { [weak self] (item, completion) in
        self?.handleItemSelection(item)
        completion()
      }

      return item
    })

    items.first?.isPlaying = true

    let section = CPListSection(items: items)
    let listTemplate = CPListTemplate(title: "recent_title".localized, sections: [section])

    self.interfaceController?.setRootTemplate(listTemplate, animated: false, completion: nil)
  }

  func formatSpeed(_ speed: Float) -> String {
    return (speed.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(speed))" : "\(speed)") + "×"
  }
}

// MARK: - Skip Chapter buttons

extension CarPlayManager {
  func hasChapter(before chapter: PlayableChapter?) -> Bool {
    guard let chapter = chapter else { return false }
    return self.mainCoordinator.playerManager.currentItem?.hasChapter(before: chapter) ?? false
  }

  func hasChapter(after chapter: PlayableChapter?) -> Bool {
    guard let chapter = chapter else { return false }
    return self.mainCoordinator.playerManager.currentItem?.hasChapter(after: chapter) ?? false
  }

  func getPreviousChapterButton() -> CPNowPlayingImageButton {
    let prevChapterImageName = self.hasChapter(before: self.mainCoordinator.playerManager.currentItem?.currentChapter)
    ? "chevron.left"
    : "chevron.left.2"

    return CPNowPlayingImageButton(image: UIImage(systemName: prevChapterImageName)!) { [weak self] _ in
      if let currentChapter = self?.mainCoordinator.playerManager.currentItem?.currentChapter,
         let previousChapter = self?.mainCoordinator.playerManager.currentItem?.previousChapter(before: currentChapter) {
        self?.mainCoordinator.playerManager.jumpTo(previousChapter.start + 0.5, recordBookmark: false)
      } else {
        self?.mainCoordinator.playerManager.playPreviousItem()
      }
    }
  }

  func getNextChapterButton() -> CPNowPlayingImageButton {
    let nextChapterImageName = self.hasChapter(after: self.mainCoordinator.playerManager.currentItem?.currentChapter)
    ? "chevron.right"
    : "chevron.right.2"

    return CPNowPlayingImageButton(image: UIImage(systemName: nextChapterImageName)!) { [weak self] _ in
      if let currentChapter = self?.mainCoordinator.playerManager.currentItem?.currentChapter,
         let nextChapter = self?.mainCoordinator.playerManager.currentItem?.nextChapter(after: currentChapter) {
        self?.mainCoordinator.playerManager.jumpTo(nextChapter.start + 0.5, recordBookmark: false)
      } else {
        self?.mainCoordinator.playerManager.playNextItem(autoPlayed: false)
      }
    }
  }
}

// MARK: - Chapter List Template

extension CarPlayManager {
  func showChapterListTemplate() {
    guard
      let chapters = self.mainCoordinator.playerManager.currentItem?.chapters
    else { return }

    let chapterItems = chapters.enumerated().map({ [weak self] (index, chapter) -> CPListItem in
      let chapterTitle = chapter.title == ""
      ? String.localizedStringWithFormat("chapter_number_title".localized, index + 1)
      : chapter.title

      let chapterDetail = String.localizedStringWithFormat("chapters_item_description".localized, TimeParser.formatTime(chapter.start), TimeParser.formatTime(chapter.duration))

      let item = CPListItem(text: chapterTitle, detailText: chapterDetail)

      if let currentChapter = self?.mainCoordinator.playerManager.currentItem?.currentChapter,
         currentChapter.index == chapter.index {
        item.isPlaying = true
      }

      item.handler = { [weak self] (_, completion) in
        NotificationCenter.default.post(
          name: .messageReceived,
          object: self,
          userInfo: [
            "command": Command.chapter.rawValue,
            "start": "\(chapter.start)"
          ]
        )
        completion()
        self?.interfaceController?.popTemplate(animated: true, completion: nil)
      }
      return item
    })

    let section = CPListSection(items: chapterItems)

    let listTemplate = CPListTemplate(title: "chapters_title".localized, sections: [section])

    self.interfaceController?.pushTemplate(listTemplate, animated: true, completion: nil)
  }
}

// MARK: - Playback Controls

extension CarPlayManager {
  func showPlaybackControlsTemplate() {
    let boostTitle = UserDefaults.standard.bool(forKey: Constants.UserDefaults.boostVolumeEnabled.rawValue)
    ? "\("settings_boostvolume_title".localized): \("active_title".localized)"
    : "\("settings_boostvolume_title".localized): \("sleep_off_title".localized)"

    boostVolumeItem.setText(boostTitle)

    let section1 = CPListSection(items: [boostVolumeItem])

    let currentSpeed = mainCoordinator.playerManager.currentSpeed
    let formattedSpeed = formatSpeed(currentSpeed)

    let speedItems = self.getSpeedOptions()
      .map({ interval -> CPListItem in
        let item = CPListItem(text: formatSpeed(interval), detailText: nil)
        item.handler = { [weak self] (_, completion) in
          let roundedValue = round(interval * 100) / 100.0

          NotificationCenter.default.post(
            name: .messageReceived,
            object: self,
            userInfo: [
              "command": Command.speed.rawValue,
              "rate": "\(roundedValue)"
            ]
          )

          self?.interfaceController?.popTemplate(animated: true, completion: nil)
          completion()
        }
        return item
      })

    let section2 = CPListSection(items: speedItems, header: "\("player_speed_title".localized): \(formattedSpeed)", sectionIndexTitle: nil)

    let listTemplate = CPListTemplate(title: "settings_controls_title".localized, sections: [section1, section2])

    self.interfaceController?.pushTemplate(listTemplate, animated: true, completion: nil)
  }

  public func getSpeedOptions() -> [Float] {
    return [
      0.5, 0.6, 0.7, 0.8, 0.9,
      1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9,
      2.0, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9,
      3.0, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9,
      4.0
    ]
  }
}

extension CarPlayManager: CPInterfaceControllerDelegate {
  func templateDidAppear(_ aTemplate: CPTemplate, animated: Bool) {
    if aTemplate == self.interfaceController?.rootTemplate,
       self.needsReload {
      self.needsReload = false
      self.loadRecentItems()
      self.setRootTemplateRecentItems()
    }
  }
}
