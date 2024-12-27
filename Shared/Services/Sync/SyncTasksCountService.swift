//
//  SyncTasksCountService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/2/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Combine
import Foundation
import RealmSwift

public protocol SyncTasksCountServiceProtocol {
  func observeTasksCount() -> AnyPublisher<Int, Never>
}

public class SyncTasksCountService: SyncTasksCountServiceProtocol {
  private var token: NotificationToken?
  private var tasksCountPublisher = CurrentValueSubject<Int?, Never>(nil)

  public init() {}

  public func observeTasksCount() -> AnyPublisher<Int, Never> {
    if token == nil {
      token = RealmManager.shared.publisher(
        for: SyncTasksObject.self,
        keyPaths: ["tasks"],
        block: { [weak self] change in
          switch change {
          case .initial(let results), .update(let results, _, _, _):
            self?.tasksCountPublisher.value = results.first?.tasks.count ?? 0
          case .error:
            /// Deprecated by Realm
            break
          }
      })
    }

    return tasksCountPublisher
      .compactMap({ $0 })
      .eraseToAnyPublisher()
  }
}
