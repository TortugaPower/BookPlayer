//
//  QueuedSyncTasksViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 26/5/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation
import BookPlayerKit
import Combine

protocol QueuedSyncTasksViewModelProtocol: ObservableObject {
  var allowsCellularData: Bool { get }
  var queuedJobs: [SyncTask] { get set }
}

class QueuedSyncTasksViewModel: QueuedSyncTasksViewModelProtocol {
  enum Events {
    case showAlert(content: BPAlertContent)
  }

  let syncService: SyncServiceProtocol

  @Published var queuedJobs: [SyncTask] = []
  @Published var allowsCellularData: Bool = false

  /// Reference for observers
  private var syncTasksObserver: NSKeyValueObservation?
  private var cellularDataObserver: NSKeyValueObservation?

  var eventsPublisher = InterfaceUpdater<QueuedSyncTasksViewModel.Events>()
  private var disposeBag = Set<AnyCancellable>()

  init(syncService: SyncServiceProtocol) {
    self.syncService = syncService

    self.reloadQueuedJobs()
    self.bindObservers()
  }

  func bindObservers() {
    syncTasksObserver = UserDefaults.standard.observe(\.userSyncTasksQueue) { [weak self] _, _ in
      self?.reloadQueuedJobs()
    }

    cellularDataObserver = UserDefaults.standard.observe(
      \.userSettingsAllowCellularData,
       options: [.initial, .new]
    ) { [weak self] _, change in
      guard let newValue = change.newValue else { return }

      self?.allowsCellularData = newValue
    }
  }

  func observeEvents() -> AnyPublisher<QueuedSyncTasksViewModel.Events, Never> {
    eventsPublisher.eraseToAnyPublisher()
  }

  func reloadQueuedJobs() {
    Task { @MainActor in
      queuedJobs = await syncService.getAllQueuedJobs()
    }
  }

  private func sendEvent(_ event: QueuedSyncTasksViewModel.Events) {
    eventsPublisher.send(event)
  }

  func showInfo() {
    sendEvent(.showAlert(
      content: BPAlertContent(
        title: "",
        message: "sync_tasks_alert_description".localized,
        style: .alert,
        actionItems: [
          BPActionItem(title: "ok_button".localized)
        ]
      )
    ))
  }
}
