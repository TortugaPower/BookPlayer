//
//  QueuedSyncTasksViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 26/5/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import Foundation
import BookPlayerKit
import Combine

protocol QueuedSyncTasksViewModelProtocol: ObservableObject {
  var allowsCellularData: Bool { get }
  var queuedJobs: [SyncTaskReference] { get set }
}

class QueuedSyncTasksViewModel: QueuedSyncTasksViewModelProtocol {
  enum Events {
    case showAlert(content: BPAlertContent)
  }

  let syncService: SyncServiceProtocol

  @Published var queuedJobs: [SyncTaskReference] = []
  @Published var allowsCellularData: Bool = false

  /// Reference for observers
  private var cellularDataObserver: NSKeyValueObservation?

  var eventsPublisher = InterfaceUpdater<QueuedSyncTasksViewModel.Events>()
  private var disposeBag = Set<AnyCancellable>()

  init(syncService: SyncServiceProtocol) {
    self.syncService = syncService

    self.reloadQueuedJobs()
    self.bindObservers()
  }

  func bindObservers() {
    syncService.observeTasksCount().sink { [weak self] _ in
      self?.reloadQueuedJobs()
    }
    .store(in: &disposeBag)

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
