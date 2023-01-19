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

  func showAccount()
  func syncLibrary()
}

class ProfileViewModel: BaseViewModel<ProfileCoordinator>, ProfileViewModelProtocol {
  let accountService: AccountServiceProtocol
  let libraryService: LibraryServiceProtocol
  let syncService: SyncServiceProtocol

  @Published var account: Account?
  @Published var totalListeningTimeFormatted: String = "0m"
  @Published var refreshStatusMessage: String = ""

  private var disposeBag = Set<AnyCancellable>()

  init(
    accountService: AccountServiceProtocol,
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.accountService = accountService
    self.libraryService = libraryService
    self.syncService = syncService

    super.init()

    self.reloadAccount()
    self.reloadListenedTime()
    self.bindObservers()
  }

  func bindObservers() {
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
  }

  func reloadAccount() {
    self.account = self.accountService.getAccount()
  }

  func showAccount() {
    self.coordinator.showAccount()
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
      try? await self?.syncService.syncLibrary()
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
