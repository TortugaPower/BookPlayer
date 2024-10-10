//
//  CarPlayManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 8/12/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import CarPlay
import Combine

class CarPlayManager: NSObject {
  var interfaceController: CPInterfaceController?
  weak var recentTemplate: CPListTemplate?
  weak var libraryTemplate: CPListTemplate?

  private var disposeBag = Set<AnyCancellable>()
  /// Reference for updating boost volume title
  let boostVolumeItem = CPListItem(text: "", detailText: nil)

  override init() {
    super.init()

    self.bindObservers()
  }

  // MARK: - Lifecycle

  @MainActor
  func connect(_ interfaceController: CPInterfaceController) {
    self.interfaceController = interfaceController
    self.interfaceController?.delegate = self
    self.setupNowPlayingTemplate()
    self.setRootTemplate()
    self.initializeDataIfNeeded()
  }

  func disconnect() {
    self.interfaceController = nil
    self.recentTemplate = nil
    self.libraryTemplate = nil
  }

  @MainActor
  func initializeDataIfNeeded() {
    guard
      AppDelegate.shared?.activeSceneDelegate == nil
    else { return }

    let dataInitializerCoordinator = DataInitializerCoordinator(alertPresenter: self)

    dataInitializerCoordinator.onFinish = { [weak self] in
      self?.setRootTemplate()
      AppDelegate.shared?.coreServices?.watchService.startSession()
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

        self.reloadRecentItems()

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
      let flag = UserDefaults.standard.bool(forKey: Constants.UserDefaults.boostVolumeEnabled)

      NotificationCenter.default.post(
        name: .messageReceived,
        object: self,
        userInfo: [
          "command": Command.boostVolume.rawValue,
          "isOn": "\(!flag)",
        ]
      )

      let boostTitle =
        !flag
        ? "\("settings_boostvolume_title".localized): \("active_title".localized)"
        : "\("settings_boostvolume_title".localized): \("sleep_off_title".localized)"

      self?.boostVolumeItem.setText(boostTitle)
      completion()
    }
  }

  func loadLibraryItems(at relativePath: String?) -> [SimpleLibraryItem] {
    guard
      let libraryService = AppDelegate.shared?.coreServices?.libraryService
    else { return [] }

    return libraryService.fetchContents(at: relativePath, limit: nil, offset: nil) ?? []
  }

  // swiftlint:disable:next function_body_length
  func setupNowPlayingTemplate() {
    guard
      let coreServices = AppDelegate.shared?.coreServices
    else { return }

    let libraryService = coreServices.libraryService
    let playerManager = coreServices.playerManager

    let prevButton = self.getPreviousChapterButton()

    let nextButton = self.getNextChapterButton()

    let controlsButton = CPNowPlayingImageButton(
      image: UIImage(named: "carplay.dial.max")!
    ) { [weak self] _ in
      self?.showPlaybackControlsTemplate()
    }

    let listButton = CPNowPlayingImageButton(
      image: UIImage(named: "carplay.list.bullet")!
    ) { [weak self] _ in
      if UserDefaults.standard.bool(forKey: Constants.UserDefaults.playerListPrefersBookmarks) {
        self?.showBookmarkListTemplate()
      } else {
        self?.showChapterListTemplate()
      }
    }

    let bookmarksButton = CPNowPlayingImageButton(
      image: UIImage(named: "toolbarIconBookmark")!
    ) { [weak self, libraryService, playerManager] _ in
      guard
        let self = self,
        let currentItem = playerManager.currentItem
      else { return }

      let alertTitle: String
      let currentTime = floor(currentItem.currentTime)

      if let bookmark = libraryService.createBookmark(
        at: currentTime,
        relativePath: currentItem.relativePath,
        type: .user
      ) {
        coreServices.syncService.scheduleSetBookmark(
          relativePath: currentItem.relativePath,
          time: currentTime,
          note: nil
        )
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

    CPNowPlayingTemplate.shared.updateNowPlayingButtons([
      prevButton, controlsButton, bookmarksButton, listButton, nextButton,
    ])
  }

  /// Setup root Tab bar template with the Recent and Library tabs
  func setRootTemplate() {
    let recentTemplate = CPListTemplate(title: "recent_title".localized, sections: [])
    self.recentTemplate = recentTemplate
    recentTemplate.tabTitle = "recent_title".localized
    recentTemplate.tabImage = UIImage(systemName: "clock")
    let libraryTemplate = CPListTemplate(title: "library_title".localized, sections: [])
    self.libraryTemplate = libraryTemplate
    libraryTemplate.tabTitle = "library_title".localized
    libraryTemplate.tabImage = UIImage(systemName: "books.vertical")
    let tabTemplate = CPTabBarTemplate(templates: [recentTemplate, libraryTemplate])
    tabTemplate.delegate = self
    self.interfaceController?.setRootTemplate(tabTemplate, animated: false, completion: nil)
  }

  /// Reload content for the root library template
  func reloadLibraryList() {
    let items = getLibraryContents()
    let section = CPListSection(items: items)
    self.libraryTemplate?.updateSections([section])
  }

  /// Push new list template with the selected folder contents
  func pushLibraryList(at relativePath: String?, templateTitle: String) {
    let items = getLibraryContents(at: relativePath)
    let section = CPListSection(items: items)
    let listTemplate = CPListTemplate(title: templateTitle, sections: [section])
    self.interfaceController?.pushTemplate(listTemplate, animated: true, completion: nil)
  }

  /// Returns the library contents at a specified level
  func getLibraryContents(at relativePath: String? = nil) -> [CPListItem] {
    guard
      let libraryService = AppDelegate.shared?.coreServices?.libraryService
    else { return [] }

    let items = libraryService.fetchContents(at: relativePath, limit: nil, offset: nil) ?? []

    return transformItems(items)
  }

  /// Transforms the interface `SimpleLibraryItem` into CarPlay items
  func transformItems(_ items: [SimpleLibraryItem]) -> [CPListItem] {
    return items.map { simpleItem -> CPListItem in
      let item = CPListItem(
        text: simpleItem.title,
        detailText: simpleItem.details,
        image: UIImage(contentsOfFile: ArtworkService.getCachedImageURL(for: simpleItem.relativePath).path)
      )
      item.playbackProgress = CGFloat(simpleItem.percentCompleted / 100)
      item.handler = { [weak self, simpleItem] (_, completion) in
        switch simpleItem.type {
        case .book, .bound:
          self?.playItem(with: simpleItem.relativePath)
        case .folder:
          self?.pushLibraryList(at: simpleItem.relativePath, templateTitle: simpleItem.title)
        }
        completion()
      }

      return item
    }
  }

  /// Reloads the recent items tab
  func reloadRecentItems() {
    guard
      let libraryService = AppDelegate.shared?.coreServices?.libraryService
    else { return }

    let items = libraryService.getLastPlayedItems(limit: 20) ?? []

    let cpitems = transformItems(items)

    cpitems.first?.isPlaying = true

    let section = CPListSection(items: cpitems)
    self.recentTemplate?.updateSections([section])
  }

  /// Handle playing the selected item
  func playItem(with relativePath: String) {
    Task { @MainActor in
      let alertPresenter: AlertPresenter = self
      do {
        try await AppDelegate.shared?.coreServices?.playerLoaderService.loadPlayer(
          relativePath,
          autoplay: true
        )
        /// Avoid trying to show the now playing screen if it's already shown
        if self.interfaceController?.topTemplate != CPNowPlayingTemplate.shared {
          self.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
        }
      } catch BPPlayerError.fileMissing {
        alertPresenter.showAlert(
          "file_missing_title".localized,
          message:
            "\("file_missing_description".localized)\n\(relativePath)",
          completion: nil
        )
      } catch {
        alertPresenter.showAlert(
          "error_title".localized,
          message: error.localizedDescription,
          completion: nil
        )
      }
    }
  }

  func formatSpeed(_ speed: Float) -> String {
    return (speed.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(speed))" : "\(speed)") + "×"
  }
}

// MARK: - Skip Chapter buttons

extension CarPlayManager {
  func hasChapter(before chapter: PlayableChapter?) -> Bool {
    guard
      let playerManager = AppDelegate.shared?.coreServices?.playerManager,
      let chapter = chapter
    else { return false }

    return playerManager.currentItem?.hasChapter(before: chapter) ?? false
  }

  func hasChapter(after chapter: PlayableChapter?) -> Bool {
    guard
      let playerManager = AppDelegate.shared?.coreServices?.playerManager,
      let chapter = chapter
    else { return false }

    return playerManager.currentItem?.hasChapter(after: chapter) ?? false
  }

  func getPreviousChapterButton() -> CPNowPlayingImageButton {
    let prevChapterImageName =
      self.hasChapter(before: AppDelegate.shared?.coreServices?.playerManager.currentItem?.currentChapter)
      ? "carplay.chevron.left"
      : "carplay.chevron.left.2"

    return CPNowPlayingImageButton(
      image: UIImage(named: prevChapterImageName)!
    ) { _ in
      guard let playerManager = AppDelegate.shared?.coreServices?.playerManager else { return }

      if let currentChapter = playerManager.currentItem?.currentChapter,
        let previousChapter = playerManager.currentItem?.previousChapter(before: currentChapter)
      {
        playerManager.jumpToChapter(previousChapter)
      } else {
        playerManager.playPreviousItem()
      }
    }
  }

  func getNextChapterButton() -> CPNowPlayingImageButton {
    let nextChapterImageName =
      self.hasChapter(after: AppDelegate.shared?.coreServices?.playerManager.currentItem?.currentChapter)
      ? "carplay.chevron.right"
      : "carplay.chevron.right.2"

    return CPNowPlayingImageButton(
      image: UIImage(named: nextChapterImageName)!
    ) { _ in
      guard let playerManager = AppDelegate.shared?.coreServices?.playerManager else { return }

      if let currentChapter = playerManager.currentItem?.currentChapter,
        let nextChapter = playerManager.currentItem?.nextChapter(after: currentChapter)
      {
        playerManager.jumpToChapter(nextChapter)
      } else {
        playerManager.playNextItem(autoPlayed: false, shouldAutoplay: true)
      }
    }
  }
}

// MARK: - Chapter List Template

extension CarPlayManager {
  func showChapterListTemplate() {
    guard
      let playerManager = AppDelegate.shared?.coreServices?.playerManager,
      let chapters = playerManager.currentItem?.chapters
    else { return }

    let chapterItems = chapters.enumerated().map({ [weak self, playerManager] (index, chapter) -> CPListItem in
      let chapterTitle =
        chapter.title == ""
        ? String.localizedStringWithFormat("chapter_number_title".localized, index + 1)
        : chapter.title

      let chapterDetail = String.localizedStringWithFormat(
        "chapters_item_description".localized,
        TimeParser.formatTime(chapter.start),
        TimeParser.formatTime(chapter.duration)
      )

      let item = CPListItem(text: chapterTitle, detailText: chapterDetail)

      if let currentChapter = playerManager.currentItem?.currentChapter,
        currentChapter.index == chapter.index
      {
        item.isPlaying = true
      }

      item.handler = { [weak self] (_, completion) in
        NotificationCenter.default.post(
          name: .messageReceived,
          object: self,
          userInfo: [
            "command": Command.chapter.rawValue,
            "start": "\(chapter.start)",
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
  func createBookmarkCPItem(from bookmark: SimpleBookmark, includeImage: Bool) -> CPListItem {
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
          "start": "\(bookmark.time)",
        ]
      )
      completion()
      self?.interfaceController?.popTemplate(animated: true, completion: nil)
    }

    return item
  }

  func showBookmarkListTemplate() {
    guard
      let coreServices = AppDelegate.shared?.coreServices,
        let currentItem = coreServices.playerManager.currentItem
    else { return }

    let libraryService = coreServices.libraryService

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

    let section1 = CPListSection(
      items: automaticItems,
      header: "bookmark_type_automatic_title".localized,
      sectionIndexTitle: nil
    )

    let section2 = CPListSection(items: userItems, header: "bookmark_type_user_title".localized, sectionIndexTitle: nil)

    let listTemplate = CPListTemplate(title: "bookmarks_title".localized, sections: [section1, section2])

    self.interfaceController?.pushTemplate(listTemplate, animated: true, completion: nil)
  }
}

// MARK: - Playback Controls

extension CarPlayManager {
  func showPlaybackControlsTemplate() {
    let boostTitle =
      UserDefaults.standard.bool(forKey: Constants.UserDefaults.boostVolumeEnabled)
      ? "\("settings_boostvolume_title".localized): \("active_title".localized)"
      : "\("settings_boostvolume_title".localized): \("sleep_off_title".localized)"

    boostVolumeItem.setText(boostTitle)

    let section1 = CPListSection(items: [boostVolumeItem])

    let currentSpeed = AppDelegate.shared?.coreServices?.playerManager.currentSpeed ?? 1
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
              "rate": "\(roundedValue)",
            ]
          )

          self?.interfaceController?.popTemplate(animated: true, completion: nil)
          completion()
        }
        return item
      })

    let section2 = CPListSection(
      items: speedItems,
      header: "\("player_speed_title".localized): \(formattedSpeed)",
      sectionIndexTitle: nil
    )

    let listTemplate = CPListTemplate(title: "settings_controls_title".localized, sections: [section1, section2])

    self.interfaceController?.pushTemplate(listTemplate, animated: true, completion: nil)
  }

  public func getSpeedOptions() -> [Float] {
    return [
      0.5, 0.6, 0.7, 0.8, 0.9,
      1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9,
      2.0, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9,
      3.0, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9,
      4.0,
    ]
  }
}

extension CarPlayManager: CPInterfaceControllerDelegate {}

extension CarPlayManager: AlertPresenter {
  func showLoader() {}
  func stopLoader() {}

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

extension CarPlayManager: CPTabBarTemplateDelegate {
  func tabBarTemplate(_ tabBarTemplate: CPTabBarTemplate, didSelect selectedTemplate: CPTemplate) {
    switch selectedTemplate {
    case selectedTemplate where selectedTemplate == self.recentTemplate:
      reloadRecentItems()
    case selectedTemplate where selectedTemplate == self.libraryTemplate:
      reloadLibraryList()
    default:
      break
    }
  }
}
