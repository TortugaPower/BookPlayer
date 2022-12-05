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

class ProfileViewModel: BaseViewModel<ProfileCoordinator>, ProfileListenedTimeViewModel {
  let accountService: AccountServiceProtocol
  let libraryService: LibraryServiceProtocol

  @Published var account: Account?
  @Published var totalListeningTimeFormatted: String = "0m"

  private var disposeBag = Set<AnyCancellable>()

  init(
    accountService: AccountServiceProtocol,
    libraryService: LibraryServiceProtocol
  ) {
    self.accountService = accountService
    self.libraryService = libraryService

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

  func reloadListenedTime() {
    let time = libraryService.getTotalListenedTime()

    guard let formattedTime = formatTime(time) else { return }

    totalListeningTimeFormatted = formattedTime
  }

  func formatTime(_ time: Double) -> String? {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.year, .day, .hour, .minute]
    formatter.unitsStyle = .abbreviated

    return formatter.string(from: time)
  }
}
