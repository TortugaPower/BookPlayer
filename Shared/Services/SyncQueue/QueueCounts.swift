//
//  QueueCounts.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Combine
import Foundation

/// Pending-task count per queue key, published by the engine that owns every lane.
/// A drained lane is simply absent from the snapshot; `count(in:)` reads it as zero.
public struct QueueCounts: Equatable {
  public let byQueueKey: [String: Int]

  public init(byQueueKey: [String: Int] = [:]) {
    self.byQueueKey = byQueueKey
  }

  /// Every queued task across all lanes
  public var total: Int { byQueueKey.values.reduce(0, +) }

  public func count(in queueKey: String) -> Int { byQueueKey[queueKey] ?? 0 }
}

extension Publisher where Output == QueueCounts, Failure == Never {
  /// `true` whenever the given lane has nothing queued. Background refresh waits on the
  /// `sync` lane through this, so the policy reads the same at the call site and in tests.
  public func laneDrained(_ queueKey: String) -> AnyPublisher<Bool, Never> {
    map { $0.count(in: queueKey) == 0 }.eraseToAnyPublisher()
  }
}
