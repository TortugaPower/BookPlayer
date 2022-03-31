//
//  PlayerCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit
import BookPlayerKit

enum PlayerActionRoutes {
  case setSleepTimer(_ seconds: Double)
}

class PlayerCoordinator: Coordinator {
  public var onAction: Transition<PlayerActionRoutes>?
  let playerManager: PlayerManagerProtocol
  let libraryService: LibraryServiceProtocol
  weak var alert: UIAlertController?

  init(navigationController: UINavigationController,
       playerManager: PlayerManagerProtocol,
       libraryService: LibraryServiceProtocol) {
    self.playerManager = playerManager
    self.libraryService = libraryService

    super.init(navigationController: navigationController, flowType: .modal)
  }

  override func start() {
    let vc = PlayerViewController.instantiate(from: .Player)
    let viewModel = PlayerViewModel(playerManager: self.playerManager,
                                    libraryService: self.libraryService)
    viewModel.coordinator = self
    vc.viewModel = viewModel
    self.navigationController.present(vc, animated: true, completion: nil)
    self.presentingViewController = vc
  }

  func showBookmarks() {
    let bookmarksCoordinator = BookmarkCoordinator(navigationController: self.navigationController,
                                                   playerManager: self.playerManager,
                                                   libraryService: self.libraryService)
    bookmarksCoordinator.parentCoordinator = self
    bookmarksCoordinator.presentingViewController = self.presentingViewController
    self.childCoordinators.append(bookmarksCoordinator)
    bookmarksCoordinator.start()
  }

  func showChapters() {
    let chaptersCoordinator = ChapterCoordinator(navigationController: self.navigationController,
                                                 playerManager: self.playerManager)
    chaptersCoordinator.parentCoordinator = self
    chaptersCoordinator.presentingViewController = self.presentingViewController
    self.childCoordinators.append(chaptersCoordinator)
    chaptersCoordinator.start()
  }

  func showControls() {
    let playerControlsCoordinator = PlayerControlsCoordinator(
      navigationController: self.navigationController,
      playerManager: self.playerManager
    )
    playerControlsCoordinator.parentCoordinator = self
    playerControlsCoordinator.presentingViewController = self.presentingViewController
    self.childCoordinators.append(playerControlsCoordinator)
    playerControlsCoordinator.start()
  }

  func showSleepTimerActions() {
    let formatter = DateComponentsFormatter()

    formatter.unitsStyle = .full
    formatter.allowedUnits = [.hour, .minute]

    let alertController = UIAlertController(
      title: nil,
      message: SleepTimer.shared.getAlertMessage(),
      preferredStyle: .actionSheet
    )

    alertController.addAction(UIAlertAction(title: "sleep_off_title".localized, style: .default, handler: { [weak self] _ in
      self?.onAction?(.setSleepTimer(-1))
    }))

    for interval in SleepTimer.shared.intervals {
      let formattedDuration = formatter.string(from: interval as TimeInterval)!

      alertController.addAction(
        UIAlertAction(
          title: String.localizedStringWithFormat("sleep_interval_title".localized, formattedDuration),
          style: .default,
          handler: { [weak self] _ in
            self?.onAction?(.setSleepTimer(interval))
          }
        )
      )
    }

    alertController.addAction(UIAlertAction(title: "sleep_chapter_option_title".localized, style: .default) { [weak self] _ in
      self?.onAction?(.setSleepTimer(-2))
    })

    alertController.addAction(UIAlertAction(title: "sleeptimer_option_custom".localized, style: .default) { [weak self] _ in
      self?.showCustomSleepTimerOption()
    })

    alertController.addAction(
      UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil)
    )

    self.presentingViewController?.present(alertController, animated: true, completion: nil)
    SleepTimer.shared.alert = alertController
  }

  func showCustomSleepTimerOption() {
    let customTimerAlert = UIAlertController(
      title: "sleeptimer_custom_alert_title".localized,
      message: "\n\n\n\n\n\n\n\n\n\n",
      preferredStyle: .actionSheet
    )

    let datePicker = UIDatePicker()
    datePicker.datePickerMode = .countDownTimer
    customTimerAlert.view.addSubview(datePicker)
    customTimerAlert.addAction(
      UIAlertAction(
        title: "ok_button".localized,
        style: .default,
        handler: { [weak self] _ in
          self?.onAction?(.setSleepTimer(datePicker.countDownDuration))
        }
      )
    )
    customTimerAlert.addAction(
      UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil)
    )

    datePicker.translatesAutoresizingMaskIntoConstraints = false
    datePicker.widthAnchor.constraint(
      equalToConstant: self.presentingViewController!.view.bounds.width - 16
    ).isActive = true
    datePicker.topAnchor.constraint(
      equalTo: datePicker.superview!.topAnchor,
      constant: 30
    ).isActive = true

    self.presentingViewController?.present(customTimerAlert, animated: true, completion: nil)
  }
}
