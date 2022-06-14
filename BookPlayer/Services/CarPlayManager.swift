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
  var recentItems = [PlayableItem]()

  private var disposeBag = Set<AnyCancellable>()
  /// Reference for updating boost volume title
  let boostVolumeItem = CPListItem(text: "", detailText: nil)
  /// Refresh flag in case the root template is not visible
  var needsReload = false

  override init() {
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
    self.initializeDataIfNeeded()
  }

  func disconnect() {
    self.interfaceController = nil
    self.needsReload = false
  }

  func initializeDataIfNeeded() {
    guard
      AppDelegate.shared?.dataManager == nil,
      SceneDelegate.shared == nil
    else { return }

    let dataInitializerCoordinator = DataInitializerCoordinator(alertPresenter: self)

    dataInitializerCoordinator.onFinish = { stack in
      _ = AppDelegate.shared?.createCoreServicesIfNeeded(from: stack)

      self.loadRecentItems()
      self.setRootTemplateRecentItems()
    }

    dataInitializerCoordinator.start()
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
    guard
      let libraryService = AppDelegate.shared?.libraryService,
      let playbackService = AppDelegate.shared?.playbackService
    else { return }

    if let recentBooks = libraryService.getLastPlayedItems(limit: 20) {
      recentItems = recentBooks.compactMap({ try? playbackService.getPlayableItem(from: $0) })
    }
  }

  func setupNowPlayingTemplate() {
    guard
      let libraryService = AppDelegate.shared?.libraryService,
      let playerManager = AppDelegate.shared?.playerManager
    else { return }

    let prevButton = self.getPreviousChapterButton()

    let nextButton = self.getNextChapterButton()

    let controlsButton = CPNowPlayingImageButton(image: UIImage(systemName: "dial.max")!) { [weak self] _ in
      self?.showPlaybackControlsTemplate()
    }

    let listButton = CPNowPlayingImageButton(image: UIImage(systemName: "list.bullet")!) { [weak self] _ in
      if UserDefaults.standard.bool(forKey: Constants.UserDefaults.playerListPrefersBookmarks.rawValue) {
        self?.showBookmarkListTemplate()
      } else {
        self?.showChapterListTemplate()
      }
    }

    let bookmarksButton = CPNowPlayingImageButton(image: UIImage(named: "toolbarIconBookmark")!) { [weak self, libraryService, playerManager] _ in
      guard
        let self = self,
        let currentItem = playerManager.currentItem
      else { return }

      let alertTitle: String

      if let bookmark = libraryService.createBookmark(
        at: currentItem.currentTime,
        relativePath: currentItem.relativePath,
        type: .user
      ) {
        let formattedTime = TimeParser.formatTime(bookmark.time)
        alertTitle = String.localizedStringWithFormat("bookmark_created_title".localized, formattedTime)
      } else {
        alertTitle = "file_missing_title".localized
      }

      let okAction = CPAlertAction(title: "ok_button".localized, style: .default) { _ in
        self.interfaceController?.dismissTemplate(animated: true, completion: nil)
      }
      let alertTemplate = CPAlertTemplate(titleVariants: [alertTitle], actions: [okAction])

      self.interfaceController?.presentTemplate(alertTemplate, animated: true, completion: nil)
    }

    CPNowPlayingTemplate.shared.updateNowPlayingButtons([prevButton, controlsButton, bookmarksButton, listButton, nextButton])
  }

  func handleItemSelection(_ item: CPSelectableListItem) {
    if let listTemplate = self.interfaceController?.rootTemplate as? CPListTemplate,
       let indexPath = listTemplate.indexPath(for: item) {
      let selectedItem = recentItems[indexPath.row]
      AppDelegate.shared?.loadPlayer(
        selectedItem.relativePath,
        autoplay: true,
        showPlayer: { [weak self] in
          self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
        },
        alertPresenter: self
      )
    }
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
    guard
      let playerManager = AppDelegate.shared?.playerManager,
      let chapter = chapter
    else { return false }

    return playerManager.currentItem?.hasChapter(before: chapter) ?? false
  }

  func hasChapter(after chapter: PlayableChapter?) -> Bool {
    guard
      let playerManager = AppDelegate.shared?.playerManager,
      let chapter = chapter
    else { return false }

    return playerManager.currentItem?.hasChapter(after: chapter) ?? false
  }

  func getPreviousChapterButton() -> CPNowPlayingImageButton {
    let prevChapterImageName = self.hasChapter(before: AppDelegate.shared?.playerManager?.currentItem?.currentChapter)
    ? "chevron.left"
    : "chevron.left.2"

    return CPNowPlayingImageButton(image: UIImage(systemName: prevChapterImageName)!) { _ in
      guard let playerManager = AppDelegate.shared?.playerManager else { return }

      if let currentChapter = playerManager.currentItem?.currentChapter,
         let previousChapter = playerManager.currentItem?.previousChapter(before: currentChapter) {
        playerManager.jumpTo(previousChapter.start + 0.5, recordBookmark: false)
      } else {
        playerManager.playPreviousItem()
      }
    }
  }

  func getNextChapterButton() -> CPNowPlayingImageButton {
    let nextChapterImageName = self.hasChapter(after: AppDelegate.shared?.playerManager?.currentItem?.currentChapter)
    ? "chevron.right"
    : "chevron.right.2"

    return CPNowPlayingImageButton(image: UIImage(systemName: nextChapterImageName)!) { _ in
      guard let playerManager = AppDelegate.shared?.playerManager else { return }

      if let currentChapter = playerManager.currentItem?.currentChapter,
         let nextChapter = playerManager.currentItem?.nextChapter(after: currentChapter) {
        playerManager.jumpTo(nextChapter.start + 0.5, recordBookmark: false)
      } else {
        playerManager.playNextItem(autoPlayed: false)
      }
    }
  }
}

// MARK: - Chapter List Template

extension CarPlayManager {
  func showChapterListTemplate() {
    guard
      let playerManager = AppDelegate.shared?.playerManager,
      let chapters = playerManager.currentItem?.chapters
    else { return }

    let chapterItems = chapters.enumerated().map({ [weak self, playerManager] (index, chapter) -> CPListItem in
      let chapterTitle = chapter.title == ""
      ? String.localizedStringWithFormat("chapter_number_title".localized, index + 1)
      : chapter.title

      let chapterDetail = String.localizedStringWithFormat("chapters_item_description".localized, TimeParser.formatTime(chapter.start), TimeParser.formatTime(chapter.duration))

      let item = CPListItem(text: chapterTitle, detailText: chapterDetail)

      if let currentChapter = playerManager.currentItem?.currentChapter,
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

// MARK: - Bookmark List Template

extension CarPlayManager {
  func createBookmarkCPItem(from bookmark: Bookmark, includeImage: Bool) -> CPListItem {
    let item = CPListItem(
      text: bookmark.note,
      detailText: TimeParser.formatTime(bookmark.time)
    )

    if includeImage {
      item.setAccessoryImage(UIImage(systemName: bookmark.getImageNameForType()!))
    }

    item.handler = { [weak self, bookmark] (_, completion) in
      NotificationCenter.default.post(
        name: .messageReceived,
        object: self,
        userInfo: [
          "command": Command.chapter.rawValue,
          "start": "\(bookmark.time)"
        ]
      )
      completion()
      self?.interfaceController?.popTemplate(animated: true, completion: nil)
    }

    return item
  }

  func showBookmarkListTemplate() {
    guard
      let playerManager = AppDelegate.shared?.playerManager,
      let libraryService = AppDelegate.shared?.libraryService,
      let currentItem = playerManager.currentItem
    else { return }

    let playBookmarks = libraryService.getBookmarks(of: .play, relativePath: currentItem.relativePath) ?? []
    let skipBookmarks = libraryService.getBookmarks(of: .skip, relativePath: currentItem.relativePath) ?? []

    let automaticBookmarks = (playBookmarks + skipBookmarks)
      .sorted(by: { $0.time < $1.time })

    let automaticItems = automaticBookmarks.compactMap { [weak self] bookmark -> CPListItem? in
      return self?.createBookmarkCPItem(from: bookmark, includeImage: true)
    }

    let userBookmarks = (libraryService.getBookmarks(of: .user, relativePath: currentItem.relativePath) ?? [])
      .sorted(by: { $0.time < $1.time })

    let userItems = userBookmarks.compactMap { [weak self] bookmark -> CPListItem? in
      return self?.createBookmarkCPItem(from: bookmark, includeImage: false)
    }

    let section1 = CPListSection(items: automaticItems, header: "bookmark_type_automatic_title".localized, sectionIndexTitle: nil)

    let section2 = CPListSection(items: userItems, header: "bookmark_type_user_title".localized, sectionIndexTitle: nil)

    let listTemplate = CPListTemplate(title: "bookmarks_title".localized, sections: [section1, section2])

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

    let currentSpeed = AppDelegate.shared?.playerManager?.currentSpeed ?? 1
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

extension CarPlayManager: AlertPresenter {
  public func showAlert(_ title: String? = nil, message: String? = nil, completion: (() -> Void)? = nil) {
    let okAction = CPAlertAction(title: "ok_button".localized, style: .default) { _ in
      self.interfaceController?.dismissTemplate(animated: true, completion: nil)
      completion?()
    }

    var completeMessage = ""

    if let title = title {
      completeMessage += title
    }

    if let message = message {
      completeMessage += ": \(message)"
    }

    let alertTemplate = CPAlertTemplate(titleVariants: [completeMessage], actions: [okAction])

    self.interfaceController?.presentTemplate(alertTemplate, animated: true, completion: nil)
  }
}
