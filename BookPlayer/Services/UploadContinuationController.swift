//
//  UploadContinuationController.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BackgroundTasks
import BookPlayerKit
import Combine
import Foundation
import UIKit

/// What the continued task needs of `BGContinuedProcessingTask` (a seam for tests)
protocol ContinuedUploadTask: AnyObject {
  var progress: Progress { get }
  var expirationHandler: (() -> Void)? { get set }
  func updateTitle(_ title: String, subtitle: String)
  func setTaskCompleted(success: Bool)
}

extension BGContinuedProcessingTask: ContinuedUploadTask {}

/// Progress across every book of one continued run: bytes for the progress bar, and
/// "(x / n) file name" for the Live Activity's subtitle. `n` is every book seen waiting
/// since the run began (it grows as more are queued); a book no longer waiting counts as
/// done, whether it uploaded or was dropped.
struct UploadContinuationProgress {
  private(set) var order = [String]()
  private var sizes = [String: Int64]()
  private var names = [String: String]()
  private(set) var waiting = [String]()
  private var waitingSet = Set<String>()
  /// The book the upload lane is sending, and how far along it is
  private(set) var current: (uuid: String, fraction: Double)?

  mutating func update(waiting pending: [PendingBookUpload]) {
    for book in pending {
      if sizes[book.uuid] == nil {
        order.append(book.uuid)
      }
      // The largest size seen: a file read as 0 once mustn't shrink the total
      sizes[book.uuid] = max(sizes[book.uuid] ?? 0, book.fileSize)
      names[book.uuid] = book.fileName
    }
    waiting = pending.map(\.uuid)
    waitingSet = Set(waiting)
    if let current, !waitingSet.contains(current.uuid) {
      self.current = nil
    }
  }

  mutating func updateProgress(uuid: String, fraction: Double) {
    guard waitingSet.contains(uuid) else { return }
    current = (uuid, min(max(fraction, 0), 1))
  }

  var isFinished: Bool { waiting.isEmpty }

  var totalBytes: Int64 { sizes.values.reduce(0, +) }

  var completedBytes: Int64 {
    let done = sizes.reduce(Int64(0)) { $0 + (waitingSet.contains($1.key) ? 0 : $1.value) }
    guard let current, let size = sizes[current.uuid] else { return done }
    return done + Int64(Double(size) * current.fraction)
  }

  /// 1-based position of the book being sent (or next up), and how many there are
  var position: (index: Int, count: Int) {
    let done = order.count - waiting.count
    return (min(done + 1, max(order.count, 1)), order.count)
  }

  /// The book being sent, else the next one waiting
  var currentFileName: String? {
    let uuid = current?.uuid ?? waiting.first
    return uuid.flatMap { names[$0] }
  }
}

/// Keeps book uploads running at full speed while the app is in the background, through a
/// `BGContinuedProcessingTask` (its Live Activity: "Uploading files", "(x / n) name").
/// Submitted whenever books are queued for upload (an import, the first sync after signing
/// in or subscribing); covers the whole queue, not one book,
/// and ends when nothing is waiting — or nothing can move (a blocked lane, no S3 access).
/// When it expires (or the user cancels it) the parts keep going in the background
/// sessions, only slower.
@MainActor
@Observable
final class UploadContinuationController: BPLogger {
  enum State: Equatable {
    case idle
    /// Submitted; iOS hasn't launched it yet
    case starting
    case running
  }

  struct Dependencies {
    /// Whether this account's uploads reach S3 now (PRO, sync on)
    var canUpload: () -> Bool
    /// The transfer setting allows uploading on the current network
    var networkAllowsUploads: () -> Bool
    /// iOS only accepts a continued task from the foreground
    var isForeground: () -> Bool
    var pendingUploads: () async -> PendingBookUploads
    var submit: (BGTaskRequest) async throws -> Void
    /// Whether iOS still holds the submitted request (it may drop a queued one)
    var hasPendingRequest: () async -> Bool
    /// The queue's counts: a change can mean a book finished, was added or got blocked
    var queueChanges: () -> AnyPublisher<QueueCounts, Never>
    /// A queue that's empty for this long is done (a book moving between lanes shows up
    /// again within it)
    var confirmEmptyAfter: Duration = .seconds(1)
  }

  static let identifier = "\(Bundle.main.configurationString(for: .bundleIdentifier)).uploads.continued"

  private(set) var state = State.idle

  @ObservationIgnored private var dependencies: Dependencies?
  @ObservationIgnored private var task: ContinuedUploadTask?
  /// A task iOS launched before the services were up (a cold launch into it)
  @ObservationIgnored private var heldTask: ContinuedUploadTask?
  @ObservationIgnored private var progress = UploadContinuationProgress()
  @ObservationIgnored private var counts = QueueCounts()
  @ObservationIgnored private var subscriptions = Set<AnyCancellable>()
  @ObservationIgnored private var queueSubscription: AnyCancellable?
  @ObservationIgnored private var lastSubtitle: String?
  @ObservationIgnored private var queuedObserver: NSObjectProtocol?
  @ObservationIgnored private var isRefreshing = false
  @ObservationIgnored private var refreshAgain = false

  /// Wired once the core services exist
  func setup(dependencies: Dependencies) {
    self.dependencies = dependencies
    // Always current, so a submit can tell a queue that can't move (a blocked lane); a
    // running task re-reads on it. Throttled: every store and pop changes the counts.
    queueSubscription = dependencies.queueChanges()
      .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
      .sink { [weak self] counts in
        guard let self else { return }
        self.counts = counts
        if self.task != nil {
          Task { await self.refresh() }
        }
      }
    queuedObserver = NotificationCenter.default.addObserver(
      forName: .bookUploadsQueued,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        Task { await self.submitIfNeeded() }
      }
    }
    if let heldTask {
      self.heldTask = nil
      attach(heldTask)
    }
  }

  /// Registered at launch: iOS calls it with the task, on a queue of its own
  static func register(controller: @escaping @MainActor () -> UploadContinuationController) {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
      guard let task = task as? BGContinuedProcessingTask else {
        task.setTaskCompleted(success: false)
        return
      }
      Task { @MainActor in controller().attach(task) }
    }
  }

  func submitIfNeeded() async {
    guard let dependencies else { return }
    // A request iOS accepted but dropped (or never ran) mustn't block every later one
    if state == .starting, await !dependencies.hasPendingRequest(), state == .starting {
      state = .idle
    }
    guard state == .idle else { return }
    guard
      dependencies.isForeground(),
      dependencies.canUpload(),
      dependencies.networkAllowsUploads()
    else { return }

    let pending = await dependencies.pendingUploads()
    // Nothing waiting, or nothing that can move (e.g. behind a paused lane): a Live
    // Activity that fails at once helps no one
    guard state == .idle, !pending.books.isEmpty, canMakeProgress(pending) else { return }

    var initial = UploadContinuationProgress()
    initial.update(waiting: pending.books)
    let request = BGContinuedProcessingTaskRequest(
      identifier: Self.identifier,
      title: Self.title,
      subtitle: Self.subtitle(for: initial)
    )
    state = .starting
    do {
      try await dependencies.submit(request)
      Self.logger.info("Continued upload task submitted for \(pending.books.count) book(s)")
    } catch {
      Self.logger.error("Continued upload task not submitted: \(error.localizedDescription)")
      state = .idle
    }
  }

  func attach(_ task: ContinuedUploadTask) {
    // Answered first, whatever else happens: also what cancelling the Live Activity calls.
    // Answered here, on iOS's queue, not after a hop to main; the parts carry on in the
    // background sessions.
    task.expirationHandler = { [weak self, weak task] in
      task?.setTaskCompleted(success: false)
      Task { @MainActor in
        guard let self, let task else { return }
        // Expired while held: never attach it later
        if self.heldTask === task {
          self.heldTask = nil
        }
        guard self.task === task else { return }
        self.finish(success: false, reason: "expired", alreadyCompleted: true)
      }
    }
    guard let dependencies else {
      heldTask = task
      return
    }
    // A second launch replaces the first run
    if self.task != nil {
      finish(success: false, reason: "replaced")
    }
    self.task = task
    state = .running
    progress = UploadContinuationProgress()
    lastSubtitle = nil

    NotificationCenter.default.publisher(for: .uploadProgressUpdated)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] notification in
        guard
          let self,
          let uuid = notification.userInfo?["uuid"] as? String,
          let fraction = notification.userInfo?["progress"] as? Double
        else { return }
        self.progress.updateProgress(uuid: uuid, fraction: fraction)
        self.report()
      }
      .store(in: &subscriptions)

    Task { await refresh() }
  }

  /// One at a time, the latest state winning: a queue change during a read re-reads after
  /// it, so snapshots never apply out of order and a burst of changes costs two reads
  private func refresh() async {
    guard !isRefreshing else {
      refreshAgain = true
      return
    }
    isRefreshing = true
    defer { isRefreshing = false }
    repeat {
      refreshAgain = false
      await refreshOnce()
    } while refreshAgain && task != nil
  }

  private func refreshOnce() async {
    guard let dependencies, let task else { return }
    var pending = await dependencies.pendingUploads()
    guard self.task === task else { return }

    if pending.books.isEmpty {
      // A book moving between lanes (or handed back to the sync lane) can look absent
      // for a moment: only a queue that stays empty is done
      try? await Task.sleep(for: dependencies.confirmEmptyAfter)
      pending = await dependencies.pendingUploads()
      guard self.task === task else { return }
      guard pending.books.isEmpty else {
        progress.update(waiting: pending.books)
        report()
        return
      }
      progress.update(waiting: [])
      // The bar ends full (also when no size could be read)
      task.progress.totalUnitCount = max(progress.totalBytes, 1)
      task.progress.completedUnitCount = task.progress.totalUnitCount
      let parked = pending.parkedCount > 0
      finish(success: !parked, reason: parked ? "only parked uploads left" : "queue done")
      return
    }

    progress.update(waiting: pending.books)
    guard canMakeProgress(pending) else {
      finish(success: false, reason: "nothing can upload now")
      return
    }
    report()
  }

  /// Something waiting sits in a lane that can run: no S3 access, or every waiting book
  /// behind a blocked lane (a lane-level or account-level pause), means waiting on the user
  private func canMakeProgress(_ pending: PendingBookUploads) -> Bool {
    guard let dependencies, dependencies.canUpload() else { return false }
    return pending.books.contains { !counts.isBlocked($0.queueKey) }
  }

  private func report() {
    guard let task else { return }
    task.progress.totalUnitCount = max(progress.totalBytes, 1)
    task.progress.completedUnitCount = min(progress.completedBytes, task.progress.totalUnitCount)
    // Nothing to name (the queue emptied): keep the last subtitle
    guard progress.currentFileName != nil else { return }
    let subtitle = Self.subtitle(for: progress)
    if subtitle != lastSubtitle {
      lastSubtitle = subtitle
      task.updateTitle(Self.title, subtitle: subtitle)
    }
  }

  private func finish(success: Bool, reason: String, alreadyCompleted: Bool = false) {
    guard let task else { return }
    Self.logger.info("Continued upload task done (\(reason))")
    self.task = nil
    subscriptions.removeAll()
    state = .idle
    if !alreadyCompleted {
      task.setTaskCompleted(success: success)
    }
  }

  static var title: String { "continued_upload_title".localized }

  static func subtitle(for progress: UploadContinuationProgress) -> String {
    let position = progress.position
    return String(
      format: "continued_upload_subtitle".localized,
      position.index,
      position.count,
      progress.currentFileName ?? ""
    )
  }
}
