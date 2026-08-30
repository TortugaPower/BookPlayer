//
//  ExternalImportViewModel.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 17/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//
import Combine
import Foundation
import SwiftUI
import BookPlayerKit

/// The external-import bus: integration screens send their CONFIRMED virtual-import
/// batches, LibraryRootView consumes and inserts. It carries no state — a
/// PassthroughSubject is a wire, not a store — and conforms to ObservableObject
/// solely to ride `.environmentObject`'s LOUD injection contract: a missed
/// injection crashes at first read, instead of an @Entry throwaway default
/// silently splitting producers and consumer onto different subjects.
@MainActor
final class ExternalImportBus: ObservableObject {
  let confirmedBatches = PassthroughSubject<[SimpleExternalResource], Never>()

  func send(_ resources: [SimpleExternalResource]) {
    confirmedBatches.send(resources)
  }
}

@MainActor
final class ExternalImportViewModel: ObservableObject {
  /// OWNED value state, seeded from the producer's staged batch: removals republish
  /// natively. (The previous shape was a computed passthrough onto a shared
  /// ImportManager mailbox — mutations never fired this VM's objectWillChange, so the
  /// delete button was visually dead.)
  @Published private(set) var resources: [SimpleExternalResource]
  private let onConfirm: ([SimpleExternalResource]) -> Void

  init(
    batch: ExternalImportBatch,
    onConfirm: @escaping ([SimpleExternalResource]) -> Void
  ) {
    self.resources = batch.resources
    self.onConfirm = onConfirm
  }

  func removeResource(withId id: String) {
    resources.removeAll { $0.providerId == id }
  }

  /// Hands the (possibly edited) selection back to the producing screen's VM,
  /// which sends it on the import bus and owns any post-confirm navigation.
  func confirm() {
    onConfirm(resources)
  }
}
