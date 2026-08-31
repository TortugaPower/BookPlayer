//
//  FileUploadOperation.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 26/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import Combine

class FileUploadOperation: AsyncOperation, BPLogger, @unchecked Sendable {
  /// True ONLY when the bytes actually reached the server (2xx). `didSucceed` also goes true
  /// for CONSUMED permanent failures (missing file, 4xx) so the queue stops retrying them —
  /// but those must never trigger the synced:true confirmation.
  /// Written on the URLSession delegate thread, read on the queue thread — lock-guarded.
  private var _uploadCompleted = false
  private(set) var uploadCompleted: Bool {
    get {
      stateLock.lock(); defer { stateLock.unlock() }
      return _uploadCompleted
    }
    set {
      stateLock.lock(); defer { stateLock.unlock() }
      _uploadCompleted = newValue
    }
  }
  
  // MARK: - Properties
  let fileURL: URL
  let remoteURL: URL
  let uuid: String
  
  // Inject whatever type 'self.client' is in your original code
  let client: NetworkClientProtocol
  
  // State management for the background task
  /// Guards the publish of `currentUploadTask` against a concurrent `cancel()`: without it,
  /// a logout-driven cancel can run between task creation and assignment, see nil, and the
  /// live upload survives logout. Either `cancel()` sees the published task and cancels it,
  /// or `startUploadTask` sees `isCancelled` and never resumes (resume on a cancelled
  /// URLSessionTask is a no-op, so the post-unlock resume can't revive it).
  private let stateLock = NSLock()
  private var currentUploadTask: URLSessionTask?
  private var progressSubscriber: AnyCancellable?
  private var completionSubscriber: AnyCancellable?
  private var cellularDataObserver: NSKeyValueObservation?
  
  // MARK: - Init
  init(fileURL: URL, remoteURL: URL, uuid: String, client: NetworkClientProtocol = NetworkClient()) {
    self.fileURL = fileURL
    self.remoteURL = remoteURL
    self.uuid = uuid
    self.client = client
    super.init()
  }
  
  // MARK: - Execution
  override func main() {
    guard !isCancelled else {
      self.finish()
      return
    }
    
    // Spin up the async context
    Task {
      await startUploadTask()
    }
  }
  
  // MARK: - Upload Logic
  private func startUploadTask() async {
    // A missing local file is permanent — retrying can never succeed, and a failed task
    // blocks the serial upload queue forever. Consume it instead.
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      Self.logger.error("Upload source missing for \(self.uuid), dropping task: \(self.fileURL.path)")
      self.didSucceed = true
      self.finish()
      return
    }
    // 1. Determine Session
    let allowCellular = UserDefaults.standard.bool(forKey: Constants.UserDefaults.allowCellularData)
    let session = allowCellular ? BPURLSession.shared.backgroundCellularSession : BPURLSession.shared.backgroundSession
    // 2. Create the Task
    let uploadTask = await self.client.uploadTask(
      fileURL,
      remoteURL: remoteURL,
      taskDescription: uuid,
      session: session
    )
    stateLock.lock()
    guard !isCancelled else {
      // cancel() already ran (and finished the operation) — don't resume or rebind
      stateLock.unlock()
      return
    }
    self.currentUploadTask = uploadTask
    stateLock.unlock()

    // 3. Bind everything before resuming
    bindUploadObservers()
    bindCellularObserver()
    // 4. Fire!
    uploadTask.resume()
  }
  
  /// The subscriber/observer refs are bound from the operation's Task thread, torn down
  /// by `cancel()` from whichever thread cancels (main via logout/lapse), and invalidated
  /// by the completion sink on the URLSession delegate thread — every touch goes through
  /// `stateLock`, same as `currentUploadTask`.
  private func invalidateCellularObserver() {
    stateLock.lock()
    cellularDataObserver?.invalidate()
    cellularDataObserver = nil
    stateLock.unlock()
  }

  private func bindCellularObserver() {
    // Built outside the lock (observe() can fire callbacks), published under it
    let observer = UserDefaults.standard.observe(
      \.userSettingsAllowCellularData,
       options: [.new]
    ) { [weak self] _, change in

      guard let self = self, change.newValue != nil else { return }

      // If the user toggles cellular data mid-flight, we cancel the current internal task.
      // (This triggers NSURLErrorCancelled in the completion subscriber).
      self.stateLock.lock()
      self.currentUploadTask?.cancel()
      self.stateLock.unlock()

      // Recursively restart the upload using the new session!
      Task {
        await self.startUploadTask()
      }
    }
    stateLock.lock()
    cellularDataObserver?.invalidate()
    cellularDataObserver = observer
    stateLock.unlock()
  }

  private func bindUploadObservers() {
    let progress = BPURLSession.shared.progressPublisher
      .sink { [weak self] (path, progress) in
        guard let self = self else { return }
        // CRITICAL: Only report progress if this event belongs to THIS operation — the
        // publisher is shared by ALL concurrent uploads; `path` is the emitting task's uuid.
        if path == self.uuid {
          self.onProgress?(progress)
        }
      }
    stateLock.lock()
    progressSubscriber?.cancel()
    progressSubscriber = progress
    stateLock.unlock()

    let completion = BPURLSession.shared.completionPublisher
      .sink { [weak self] (task, error) in
        guard let self = self else { return }
        
        // CRITICAL: Ensure this completion event belongs to this specific task
        guard task.taskDescription == self.uuid else { return }
        
        if let nserror = error as? NSError,
           nserror.domain == NSURLErrorDomain,
           nserror.code == NSURLErrorCancelled {
          // Deliberately NOT invalidating the cellular observer here: this cancelled
          // completion belongs to the OLD task after a mid-flight cellular toggle — the
          // replacement attempt just re-bound a fresh observer that must stay alive.
          // Do nothing! The cellular KVO observer cancelled this task
          // and is already spinning up a new one via startUploadTask().
          
        } else if let error = error {
          // Actual Failure — terminal for this operation, so the KVO can go.
          self.invalidateCellularObserver()
          Self.logger.error("Upload failed for \(self.uuid): \(error)")
          self.didSucceed = false
          self.finish()
          
        } else if let http = task.response as? HTTPURLResponse,
                  !(200...299).contains(http.statusCode) {
          self.invalidateCellularObserver()
          // error == nil is NOT success: the background delegate doesn't surface HTTP
          // failures as errors, so a rejected PUT (expired presigned URL, 403) lands here.
          // A 4xx is PERMANENT for this task — its presigned URL is frozen in the persisted
          // parameters and will never work again. The queue retries failures forever on a
          // single serial key, so keeping it failed hot-loops every 5s and blocks every
          // other upload behind it. Consume it; the item stays unsynced and a fresh upload
          // task (with a fresh URL) can be scheduled later.
          Self.logger.error("Upload rejected for \(self.uuid): HTTP \(http.statusCode)")
          self.didSucceed = (400...499).contains(http.statusCode)
          // A consumed 4xx is never retried, so its temp hard link would leak forever
          // without the same temp-dir-only cleanup the success branch does. (The
          // retryable-failure branch above deliberately KEEPS the link — retries
          // re-read the file.)
          if self.didSucceed, self.fileURL.path.hasPrefix(FileManager.default.temporaryDirectory.path) {
            try? FileManager.default.removeItem(at: self.fileURL)
          }
          self.finish()
        } else {
          self.invalidateCellularObserver()
          // Success! Clean up the temp hard link — and ONLY the temp hard link: when the
          // link was never created, fileURL falls back to the user's REAL audiobook in the
          // Processed folder, and deleting that is data loss.
          if self.fileURL.path.hasPrefix(FileManager.default.temporaryDirectory.path) {
            Task { @MainActor in
              do {
                try FileManager.default.removeItem(at: self.fileURL)
              } catch {
                Self.logger.warning("Failed to delete hard link for \(self.uuid): \(error.localizedDescription)")
              }
            }
          }
          self.uploadCompleted = true
          self.didSucceed = true
          self.finish()
        }
      }
    stateLock.lock()
    completionSubscriber?.cancel()
    completionSubscriber = completion
    stateLock.unlock()
  }
  
  // MARK: - Cleanup
  // If the Orchestrator cancels the operation entirely, we must sever all ties.
  override func cancel() {
    super.cancel()
    stateLock.lock()
    currentUploadTask?.cancel()
    cellularDataObserver?.invalidate()
    cellularDataObserver = nil
    progressSubscriber?.cancel()
    completionSubscriber?.cancel()
    stateLock.unlock()
    // A cancelled mid-flight upload leaks its temp hard link (only the success branch
    // cleans up) — same temp-dir guard so the user's real file is never touched.
    if fileURL.path.hasPrefix(FileManager.default.temporaryDirectory.path) {
      try? FileManager.default.removeItem(at: fileURL)
    }
    // The completion subscriber (which would have called finish()) was just torn down —
    // without this, an operation cancelled mid-flight stays .executing forever and its
    // OperationQueue slot is never reclaimed.
    if isExecuting { finish() }
  }
}
