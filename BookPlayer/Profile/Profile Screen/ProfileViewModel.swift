//
//  ProfileViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 12/3/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation
import BookPlayerKit
import Combine

protocol ProfileViewModelProtocol: ObservableObject {
  var account: Account? { get set }
  var totalListeningTimeFormatted: String { get set }
  var refreshStatusMessage: String { get set }
  var bottomOffset: CGFloat { get set }
  var isSyncButtonDisabled: Bool { get set }

  func showAccount()
  func syncLibrary()
}

class ProfileViewModel: BaseViewModel<ProfileCoordinator>, ProfileViewModelProtocol {
  struct ModelConstants {
    static let defaultBottomOffset = Spacing.M
    static let miniPlayerOffset = Spacing.S2 + 88
  }
  let accountService: AccountServiceProtocol
  let libraryService: LibraryServiceProtocol
  let playerManager: PlayerManagerProtocol
  let syncService: SyncServiceProtocol

  @Published var account: Account?
  @Published var totalListeningTimeFormatted: String = "0m"
  @Published var refreshStatusMessage: String = ""
  @Published var bottomOffset: CGFloat = ModelConstants.defaultBottomOffset
  @Published var isSyncButtonDisabled: Bool = false

  var syncStatusObserver: NSKeyValueObservation!
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

    if libraryService.getLibraryLastItem() != nil {
      bottomOffset =  ModelConstants.miniPlayerOffset
    }

    super.init()

    self.reloadAccount()
    self.reloadListenedTime()
    self.bindObservers()
  }

  func bindObservers() {
    UserDefaults.standard.publisher(for: \.userSettingsHasQueuedJobs)
      .receive(on: DispatchQueue.main)
      .sink(receiveValue: { [weak self] completedSync in
        self?.isSyncButtonDisabled = completedSync
      })
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .accountUpdate, object: nil)
      .sink(receiveValue: { [weak self] _ in
        self?.reloadAccount()
      })
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .bookPaused, object: nil)
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
      .dropFirst()
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
    self.coordinator.showAccount()
  }

  func updateSyncMessage(relativePath: String, progress: Double) {
    refreshStatusMessage = "\(Int(round(progress * 100)))% \(relativePath)"
  }

  func refreshSyncStatusMessage() {
    let timestamp = UserDefaults.standard.double(forKey: Constants.UserDefaults.lastSyncTimestamp.rawValue)

    guard timestamp > 0 else { return }

    let storedDate = Date(timeIntervalSince1970: timestamp)

    let timeDifference = Date().timeIntervalSince(storedDate)

    guard
      let formattedTime = formatTime(timeDifference, units: [.minute, .second])
    else { return }

    refreshStatusMessage = "Last sync: \(formattedTime) ago"
  }

  func syncLibrary() {
    Task { [weak self] in
      do {
        _ = try await self?.syncService.syncLibraryContents()
      } catch {
        print(error.localizedDescription)
      }
    }

    refreshStatusMessage = ""
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
