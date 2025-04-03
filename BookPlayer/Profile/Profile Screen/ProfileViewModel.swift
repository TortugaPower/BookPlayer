//
//  ProfileViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 12/3/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import Foundation
import BookPlayerKit
import Combine

protocol ProfileViewModelProtocol: ObservableObject {
  var account: Account? { get set }
  var totalListeningTimeFormatted: String { get set }
  var tasksButtonText: String { get set }
  var refreshStatusMessage: String { get set }
  var bottomOffset: CGFloat { get set }

  func showAccount()
  func showTasks()
}

class ProfileViewModel: ProfileViewModelProtocol {
  /// Available routes
  enum Routes {
    case showAccount
    case showQueuedTasks
  }

  /// Spacing constants for the bottom inset
  struct ModelConstants {
    static let defaultBottomOffset = Spacing.M
    static let miniPlayerOffset = Spacing.S2 + 88
  }

  /// Callback to handle actions on this screen
  public var onTransition: BPTransition<Routes>?

  let accountService: AccountServiceProtocol
  let libraryService: LibraryServiceProtocol
  let playerManager: PlayerManagerProtocol
  let syncService: SyncServiceProtocol

  @Published var account: Account?
  @Published var totalListeningTimeFormatted: String = "0m"
  @Published var tasksButtonText: String = ""
  @Published var refreshStatusMessage: String = ""
  @Published var bottomOffset: CGFloat = ModelConstants.defaultBottomOffset

  /// Reference for observer
  private var disposeBag = Set<AnyCancellable>()

  init(
    accountService: AccountServiceProtocol,
    libraryService: LibraryServiceProtocol,
    playerManager: PlayerManagerProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.accountService = accountService
    self.libraryService = libraryService
    self.playerManager = playerManager
    self.syncService = syncService

    self.reloadAccount()
    self.reloadListenedTime()
    self.bindObservers()
  }

  func bindObservers() {
    syncService.observeTasksCount().sink { [unowned self] count in
      self.tasksButtonText = String(format: "queued_sync_tasks_title".localized, count)
    }
    .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .accountUpdate, object: nil)
      .sink(receiveValue: { [weak self] _ in
        self?.reloadAccount()
      })
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .bookPaused, object: nil)
      .receive(on: DispatchQueue.main)
      .sink(receiveValue: { [weak self] _ in
        self?.reloadListenedTime()
      })
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .uploadProgressUpdated, object: nil)
      .receive(on: DispatchQueue.main)
      .sink(receiveValue: { [weak self] notification in
        guard
          let relativePath = notification.userInfo?["relativePath"] as? String,
          let progress = notification.userInfo?["progress"] as? Double
        else { return }
        self?.updateSyncMessage(relativePath: relativePath, progress: progress)
      })
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .uploadCompleted, object: nil)
      .receive(on: DispatchQueue.main)
      .sink(receiveValue: { [weak self] _ in
        self?.refreshStatusMessage = ""
      })
      .store(in: &disposeBag)

    playerManager.currentItemPublisher()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] item in
        if item == nil {
          self?.bottomOffset = ModelConstants.defaultBottomOffset
        } else {
          self?.bottomOffset = ModelConstants.miniPlayerOffset
        }
      }
      .store(in: &disposeBag)
  }

  func reloadAccount() {
    self.account = self.accountService.getAccount()
  }

  func showAccount() {
    onTransition?(.showAccount)
  }

  func updateSyncMessage(relativePath: String, progress: Double) {
    refreshStatusMessage = "\(Int(round(progress * 100)))% \(relativePath)"
  }

  func refreshSyncStatusMessage() {
    let timestamp = UserDefaults.standard.double(forKey: "\(Constants.UserDefaults.lastSyncTimestamp)_library")

    guard timestamp > 0 else { return }

    let storedDate = Date(timeIntervalSince1970: timestamp)

    let timeDifference = Date().timeIntervalSince(storedDate)

    guard
      let formattedTime = formatTime(timeDifference, units: [.day, .hour, .minute, .second])
    else { return }

    refreshStatusMessage = String(format: "last_sync_title".localized, formattedTime)
  }

  func showTasks() {
    onTransition?(.showQueuedTasks)
  }

  func reloadListenedTime() {
    let time = libraryService.getTotalListenedTime()

    guard let formattedTime = formatTime(time) else { return }

    totalListeningTimeFormatted = formattedTime
  }

  func formatTime(
    _ time: Double,
    units: NSCalendar.Unit = [.year, .day, .hour, .minute]
  ) -> String? {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = units
    formatter.unitsStyle = .abbreviated

    return formatter.string(from: time)
  }
}
