//
//  ExternalImportEvents.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

/// The events of the external-import flow: integration screens send their CONFIRMED
/// virtual-import batches, `LibraryRootView` consumes and inserts.
///
/// It carries no state — a PassthroughSubject is a wire, not a store — and conforms to
/// `ObservableObject` solely to ride `.environmentObject`'s LOUD injection contract: a
/// missed injection crashes at first read, instead of an `@Entry` throwaway default
/// silently splitting producers and consumer onto different subjects.
///
/// Owned by `MainView` as a `@StateObject`, not built by `MainCoordinator`: it is a wire
/// between SwiftUI views that the coordinator never touches, and the media-servers sheet
/// the producers live in is attached to `MainView`, so injecting there reaches every party.
@MainActor
final class ExternalImportEvents: ObservableObject {
  let confirmedBatches = PassthroughSubject<[SimpleExternalResource], Never>()

  func send(_ resources: [SimpleExternalResource]) {
    confirmedBatches.send(resources)
  }
}
