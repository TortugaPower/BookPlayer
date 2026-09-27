//
//  FileUploadOperation.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 26/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Combine
import Foundation

/// A book the upload lane refuses before talking to the server
public enum UploadFileError: Error, Equatable {
  /// Over the server's 10 GiB book ceiling: the file stays on this device
  case fileTooLarge

  public var code: String {
    switch self {
    case .fileTooLarge:
      return "file_too_large"
    }
  }

  public var message: String {
    switch self {
    case .fileTooLarge:
      return "upload_file_too_large_message".localized
    }
  }
}

/// Part math for one upload: every part but the last is exactly `partSize`
struct MultipartUploadPlan: Equatable {
  let fileSize: Int64
  let partSize: Int

  var partCount: Int {
    guard fileSize > 0 else { return 1 }
    return Int((fileSize + Int64(partSize) - 1) / Int64(partSize))
  }

  /// Byte range of a 1-based part
  func range(of partNumber: Int) -> Range<Int64> {
    let start = Int64(partNumber - 1) * Int64(partSize)
    return start..<min(start + Int64(partSize), fileSize)
  }

  func size(of partNumber: Int) -> Int64 {
    let range = range(of: partNumber)
    return range.upperBound - range.lowerBound
  }

  /// Parts still to send, oldest first: the session favours the newest tasks, so the
  /// engine hands them over in order to keep the oldest from waiting longest
  func pendingParts(done: Set<Int>, active: Set<Int>) -> [Int] {
    (1...partCount).filter { !done.contains($0) && !active.contains($0) }
  }

  /// How many more parts to slice now: the window, less what's in flight, and never more
  /// than the free disk space (beyond `reserve`) holds
  func openSlots(window: Int, active: Int, freeBytes: Int64, reserve: Int64) -> Int {
    let byDisk = max(0, (freeBytes - reserve) / Int64(partSize))
    return max(0, min(window - active, Int(min(byDisk, Int64(window)))))
  }
}

/// Uploads one book to S3 as a multipart upload (bookplayer-api docs/multipart-uploads.md).
///
/// S3 is the source of truth: every start of the operation rebuilds from S3's part list and
/// the parts the background session is still sending, so a relaunch, a missed event or an
/// app that iOS terminated mid-upload all resume without re-sending finished parts. The
/// server sets `synced` at `complete`; this operation never confirms it.
class FileUploadOperation: AsyncOperation, BPLogger, @unchecked Sendable {
  static let partSize = 64 * 1024 * 1024
  /// About the per-host connection limit: more parts in flight only age their URLs (P2b)
  static let window = 8
  static let maxFileSize: Int64 = 10 * 1024 * 1024 * 1024
  /// Fresh starts after S3 lost or rejected the upload, before the task parks
  static let restartBudget = 3
  /// Consecutive failures of one part before the whole operation is retried
  static let maxPartAttempts = 5
  /// Free space kept beyond the parts being sliced
  static let diskReserve: Int64 = 256 * 1024 * 1024
  /// With no event for this long, re-read S3 and the session: an event can be lost (e.g.
  /// delivered before this operation subscribed, after a relaunch)
  static let reconcileInterval: Duration = .seconds(30)

  let taskId: String
  let uuid: String
  /// The schedule-time temp hard link (or the Processed-folder file it fell back to)
  let fileURL: URL
  private let provider: NetworkProvider<LibraryAPI>
  private let repository: SyncQueueRepositoryProtocol
  private let transport: PartUploadTransport
  /// The book's current file in the Processed folder, looked up by uuid: iOS may purge the
  /// temp link, and the user may have moved the book since
  private let libraryFileURL: (String) async -> URL?
  /// Asked of the server at `start` (it answers the size it keeps); injectable for tests
  private let requestedPartSize: Int
  /// Free space on the volume parts are sliced to; injectable for tests
  private let freeDiskSpace: () -> Int64
  private var uploadState: MultipartUploadState

  private let lock = NSLock()
  private var _error: Error?
  /// Why the upload stopped; nil after a success or a consumed (dropped) task
  var error: Error? {
    get { lock.withLock { _error } }
    set { lock.withLock { _error = newValue } }
  }
  private var _uploadCompleted = false
  /// True only when S3 assembled the file (or already had it)
  private(set) var uploadCompleted: Bool {
    get { lock.withLock { _uploadCompleted } }
    set { lock.withLock { _uploadCompleted = newValue } }
  }
  private var runTask: Task<Void, Never>?

  init(
    taskId: String,
    uuid: String,
    fileURL: URL,
    state: MultipartUploadState,
    client: NetworkClientProtocol,
    repository: SyncQueueRepositoryProtocol,
    transport: PartUploadTransport = BackgroundPartUploadTransport.shared,
    partSize: Int = FileUploadOperation.partSize,
    freeDiskSpace: @escaping () -> Int64 = FileUploadOperation.availableDiskSpace,
    libraryFileURL: @escaping (String) async -> URL?
  ) {
    self.requestedPartSize = partSize
    self.freeDiskSpace = freeDiskSpace
    self.taskId = taskId
    self.uuid = uuid
    self.fileURL = fileURL
    self.uploadState = state
    self.provider = NetworkProvider(client: client)
    self.repository = repository
    self.transport = transport
    self.libraryFileURL = libraryFileURL
    super.init()
  }

  /// Parts are sliced here while they upload: `tmp/uploads/<uuid>/<n>.part` (background
  /// sessions only upload from files)
  static func partsDirectory(for uuid: String) -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("uploads", isDirectory: true)
      .appendingPathComponent(uuid, isDirectory: true)
  }

  // MARK: - Execution

  override func main() {
    guard !isCancelled else {
      finish()
      return
    }

    let task = Task { [weak self] in
      guard let self else { return }
      await self.run()
    }
    lock.withLock { runTask = task }
    // super.cancel() flags isCancelled before cancel() reads runTask: one of the two sees
    // the other, so a cancel racing the start still stops the run
    if isCancelled { task.cancel() }
  }

  /// Logout, lapse or a downgrade to a tier without S3. The S3 upload is left for the
  /// bucket's 7-day rule; the run stops its parts and removes its files once its loop has
  /// actually stopped (cleaning up here could race a part it's about to start).
  override func cancel() {
    super.cancel()
    let task = lock.withLock { runTask }
    task?.cancel()
    if error == nil {
      error = BookPlayerError.cancelledTask
    }
    if task == nil {
      // Never started: no parts, only the link
      removeLocalFiles()
    }
    if isExecuting { finish() }
  }

  private func run() async {
    do {
      try await upload()
      uploadCompleted = true
      removeLocalFiles()
    } catch UploadStop.dropped {
      removeLocalFiles()
    } catch is CancellationError {
      // The task was cleared under the upload (logout, lapse), or the operation cancelled
      if error == nil { error = BookPlayerError.cancelledTask }
    } catch {
      if !isCancelled {
        self.error = error
        if SyncFailurePolicy.codedFailure(error) != nil {
          // Parked: nothing reads the parts until a Retry, which starts from S3's list.
          // The link stays, so the Retry still finds the file.
          await removeParts()
        }
      }
    }
    if isCancelled {
      if error == nil { error = BookPlayerError.cancelledTask }
      await removeParts()
      removeLocalFiles()
    }
    didSucceed = error == nil
    finish()
  }

  private func removeParts() async {
    await transport.cancelParts(for: uuid)
    try? FileManager.default.removeItem(at: Self.partsDirectory(for: uuid))
  }

  private enum UploadStop: LocalizedError {
    /// Nothing to upload (the file is gone): consume the task
    case dropped
    /// S3 lost or rejected the upload: forget it and start again. `cause` is the server's
    /// answer, used as the pause reason once the restart budget runs out.
    case restart(cause: Error)
    /// A part keeps failing, or the disk has no room for one: fail the operation so the
    /// queue retries it later, from S3's part list
    case retryLater(String)

    /// What `lastSyncError` shows
    var errorDescription: String? {
      switch self {
      case .dropped:
        return "The file to upload is gone"
      case .restart(let cause):
        return "Restarting the upload: \(cause.localizedDescription)"
      case .retryLater(let reason):
        return "Upload paused, retrying later: \(reason)"
      }
    }
  }

  // MARK: - Upload

  private func upload() async throws {
    guard let sourceURL = await resolveSourceFile() else {
      Self.logger.error("Upload source missing for \(self.uuid), dropping the task")
      throw UploadStop.dropped
    }
    let fileSize = try Self.fileSize(of: sourceURL)
    guard fileSize <= Self.maxFileSize else {
      throw UploadFileError.fileTooLarge
    }
    // The file changed since the upload started (replaced on disk), or the saved state is
    // unusable: the open upload's parts no longer fit
    if uploadState.uploadId != nil, uploadState.fileSize != fileSize || uploadState.partSize <= 0 {
      try await forgetUpload(countingRestart: false)
    }

    var partsMissingAnswers = 0
    while true {
      try Task.checkCancellation()
      do {
        if uploadState.uploadId == nil {
          guard try await start(fileSize: fileSize) else { return }
          partsMissingAnswers = 0
        }
        try await sendAllParts(from: sourceURL)
        if try await complete() { return }
        // S3's list says every part is there, yet complete says some aren't: past a few
        // rounds, the upload itself is broken
        partsMissingAnswers += 1
        if partsMissingAnswers >= Self.maxPartAttempts {
          throw UploadStop.restart(cause: Self.partsMissingError)
        }
      } catch UploadStop.restart(let cause) {
        guard uploadState.restartCount < Self.restartBudget else {
          // Parks. The dead upload is forgotten and the budget reset, so a Retry (or the
          // launch retry) starts a fresh upload instead of re-parking on the same one.
          try await forgetUpload(countingRestart: false)
          uploadState.restartCount = 0
          try await saveState()
          throw cause
        }
        try await forgetUpload(countingRestart: true)
      }
    }
  }

  /// `false` when S3 already has the file (nothing to send)
  private func start(fileSize: Int64) async throws -> Bool {
    let response: StartUploadResponse = try await provider.request(
      .startUpload(uuid: uuid, fileSize: fileSize, partSize: requestedPartSize)
    )
    switch response.status {
    case .exists:
      return false
    case .started:
      let partSize = response.partSize ?? requestedPartSize
      guard let uploadId = response.uploadId, partSize > 0 else {
        throw BookPlayerError.runtimeError("Upload started without an uploadId or a usable part size")
      }
      uploadState.uploadId = uploadId
      uploadState.partSize = partSize
      uploadState.fileSize = fileSize
      try await saveState()
      return true
    }
  }

  /// Keeps up to `window` parts with the session until S3 holds every part
  private func sendAllParts(from sourceURL: URL) async throws {
    guard let uploadId = uploadState.uploadId else { return }
    let plan = MultipartUploadPlan(fileSize: uploadState.fileSize, partSize: uploadState.partSize)

    let (events, continuation) = AsyncStream<EngineEvent>.makeStream()
    // Subscribed before reading the session, so no event falls between the two
    let subscription = transport.subscribe(uuid: uuid, uploadId: uploadId) { continuation.yield(.part($0)) }
    let ticker = Task {
      while !Task.isCancelled {
        try? await Task.sleep(for: Self.reconcileInterval)
        continuation.yield(.tick)
      }
    }
    // Parts already handed to the Wi-Fi-only (or the cellular) session stay there: on a
    // change, cancel them so the next top-up resends them through the session that now applies
    let cellularObserver = UserDefaults.standard.observe(\.userSettingsAllowCellularData, options: [.new]) { _, _ in
      continuation.yield(.cellularSettingChanged)
    }
    defer {
      subscription.cancel()
      ticker.cancel()
      cellularObserver.invalidate()
      continuation.finish()
    }
    // One consumer for the whole pass
    var iterator = events.makeAsyncIterator()

    var done = try await uploadedParts(uploadId: uploadId)
    var active = await transport.activePartNumbers(for: uuid, uploadId: uploadId).subtracting(done)
    var bytesInFlight = [Int: Int64]()
    var failures = [Int: Int]()
    var expiredURLs = [Int: Int]()
    var sawEventSinceTick = false
    var lastReportedPercent = -1

    while done.count < plan.partCount {
      try Task.checkCancellation()

      let slots = plan.openSlots(
        window: Self.window,
        active: active.count,
        freeBytes: freeDiskSpace(),
        reserve: Self.diskReserve
      )
      let next = Array(plan.pendingParts(done: done, active: active).prefix(slots))
      if !next.isEmpty {
        // Fresh URLs every time: an old one may have died with its signing credentials
        for part in try await partURLs(uploadId: uploadId, partNumbers: next) {
          // Checked per part: a cancel must not start what nothing will clean up
          try Task.checkCancellation()
          let partFile = try slice(part: part.partNumber, of: sourceURL, plan: plan)
          transport.startPart(uuid: uuid, uploadId: uploadId, partNumber: part.partNumber, file: partFile, url: part.url)
          active.insert(part.partNumber)
        }
      } else if active.isEmpty {
        throw UploadStop.retryLater("no disk space for the next part")
      }

      guard let event = await iterator.next() else { throw CancellationError() }
      switch event {
      case .tick:
        guard !sawEventSinceTick else {
          sawEventSinceTick = false
          continue
        }
        done = try await uploadedParts(uploadId: uploadId)
        active = await transport.activePartNumbers(for: uuid, uploadId: uploadId).subtracting(done)
      case .cellularSettingChanged:
        // Their cancellations come back as `.resend`
        await transport.cancelParts(for: uuid)
      case .part(.progress(let partNumber, let bytesSent)):
        sawEventSinceTick = true
        // A late progress callback (the delegate queue is concurrent) for a finished part
        guard active.contains(partNumber) else { continue }
        bytesInFlight[partNumber] = bytesSent
      case .part(.finished(let partNumber, let statusCode, let error)):
        sawEventSinceTick = true
        guard active.remove(partNumber) != nil else { continue }
        bytesInFlight[partNumber] = nil
        switch Self.outcome(statusCode: statusCode, error: error) {
        case .uploaded:
          done.insert(partNumber)
          failures[partNumber] = nil
          expiredURLs[partNumber] = nil
          try? FileManager.default.removeItem(at: partFileURL(partNumber))
        case .resend:
          // Sent again at the next top-up with a fresh URL. Only a 403 counts: a URL that
          // keeps failing when fresh isn't expiring, the request itself is refused.
          if statusCode == 403 {
            expiredURLs[partNumber, default: 0] += 1
            if expiredURLs[partNumber, default: 0] >= Self.maxPartAttempts {
              throw UploadStop.retryLater("part \(partNumber) keeps being refused")
            }
          }
        case .uploadGone:
          throw UploadStop.restart(cause: Self.uploadLostError)
        case .failed:
          failures[partNumber, default: 0] += 1
          if failures[partNumber, default: 0] >= Self.maxPartAttempts {
            throw UploadStop.retryLater("part \(partNumber) keeps failing")
          }
        }
      }
      lastReportedPercent = reportProgress(
        plan: plan,
        done: done,
        bytesInFlight: bytesInFlight,
        lastReportedPercent: lastReportedPercent
      )
    }
  }

  /// `true` once S3 assembled the file; `false` when parts turned out missing (send them)
  private func complete() async throws -> Bool {
    guard let uploadId = uploadState.uploadId else { return false }
    let plan = MultipartUploadPlan(fileSize: uploadState.fileSize, partSize: uploadState.partSize)
    do {
      let _: CompleteUploadResponse = try await provider.request(
        .completeUpload(uuid: uuid, uploadId: uploadId, partCount: plan.partCount, fileSize: uploadState.fileSize)
      )
      return true
    } catch let error as BookPlayerError {
      switch Self.code(of: error) {
      case "parts_missing":
        return false
      case "upload_not_found", "invalid_parts":
        throw UploadStop.restart(cause: error)
      default:
        throw error
      }
    }
  }

  private func uploadedParts(uploadId: String) async throws -> Set<Int> {
    do {
      let response: UploadedPartsResponse = try await provider.request(
        .uploadedParts(uuid: uuid, uploadId: uploadId)
      )
      return Set(response.parts.map(\.partNumber))
    } catch let error as BookPlayerError where Self.code(of: error) == "upload_not_found" {
      throw UploadStop.restart(cause: error)
    }
  }

  private func partURLs(uploadId: String, partNumbers: [Int]) async throws -> [UploadPartURLsResponse.Part] {
    do {
      let response: UploadPartURLsResponse = try await provider.request(
        .uploadPartURLs(uuid: uuid, uploadId: uploadId, partNumbers: partNumbers)
      )
      return response.parts
    } catch let error as BookPlayerError where Self.code(of: error) == "upload_not_found" {
      throw UploadStop.restart(cause: error)
    }
  }

  /// Drops the open upload (the next pass starts a new one). Parts still in the session
  /// belong to it, so they're cancelled with their files.
  private func forgetUpload(countingRestart: Bool) async throws {
    await transport.cancelParts(for: uuid)
    try? FileManager.default.removeItem(at: Self.partsDirectory(for: uuid))
    uploadState.uploadId = nil
    if countingRestart {
      uploadState.restartCount += 1
    }
    try await saveState()
  }

  private func saveState() async throws {
    guard await repository.saveUploadState(uploadState, forTask: taskId) else {
      // Cleared by a logout or lapse while uploading
      throw CancellationError()
    }
  }

  // MARK: - Events

  private enum EngineEvent {
    case part(PartUploadEvent)
    case tick
    case cellularSettingChanged
  }

  enum PartOutcome: Equatable {
    case uploaded
    /// Send the part again (new URL); not counted as a failure
    case resend
    /// S3 no longer has the upload (NoSuchUpload)
    case uploadGone
    /// Retry the part, counted toward `maxPartAttempts`
    case failed
  }

  /// S3's answer to a part PUT (bookplayer-api docs/multipart-uploads.md): 403 = the URL
  /// expired, 404 = the upload is gone, anything else = retry the part
  static func outcome(statusCode: Int?, error: Error?) -> PartOutcome {
    if let error = error as? URLError, error.code == .cancelled {
      return .resend
    }
    guard error == nil, let statusCode else { return .failed }
    switch statusCode {
    case 200...299:
      return .uploaded
    case 403:
      return .resend
    case 404:
      return .uploadGone
    default:
      return .failed
    }
  }

  /// `complete` keeps finding gaps the part list doesn't show
  static let partsMissingError = BookPlayerError.networkErrorWithCode(
    message: "The upload keeps missing parts",
    code: "parts_missing",
    status: 409
  )

  /// A part's 404: the upload is gone, same as the server's `upload_not_found`
  static let uploadLostError = BookPlayerError.networkErrorWithCode(
    message: "The upload is no longer open",
    code: "upload_not_found",
    status: 404
  )

  static func code(of error: BookPlayerError) -> String? {
    guard case .networkErrorWithCode(_, let code, _) = error else { return nil }
    return code
  }

  // MARK: - Files

  private func resolveSourceFile() async -> URL? {
    if FileManager.default.fileExists(atPath: fileURL.path) {
      return fileURL
    }
    guard let libraryURL = await libraryFileURL(uuid),
          FileManager.default.fileExists(atPath: libraryURL.path)
    else { return nil }
    return libraryURL
  }

  private func partFileURL(_ partNumber: Int) -> URL {
    Self.partsDirectory(for: uuid).appendingPathComponent("\(partNumber).part")
  }

  /// Copies one part's bytes into its own file; reuses a complete one from an earlier pass
  private func slice(part partNumber: Int, of sourceURL: URL, plan: MultipartUploadPlan) throws -> URL {
    let partURL = partFileURL(partNumber)
    let size = plan.size(of: partNumber)
    if let existing = try? Self.fileSize(of: partURL), existing == size {
      return partURL
    }

    try FileManager.default.createDirectory(
      at: Self.partsDirectory(for: uuid),
      withIntermediateDirectories: true
    )
    FileManager.default.createFile(atPath: partURL.path, contents: nil)
    let reader = try FileHandle(forReadingFrom: sourceURL)
    let writer = try FileHandle(forWritingTo: partURL)
    defer {
      try? reader.close()
      try? writer.close()
    }

    try reader.seek(toOffset: UInt64(plan.range(of: partNumber).lowerBound))
    var remaining = size
    let chunk: Int64 = 4 * 1024 * 1024
    while remaining > 0 {
      // Drained per chunk: a part is 64 MiB, and several are sliced back to back
      try autoreleasepool {
        guard let data = try reader.read(upToCount: Int(min(chunk, remaining))), !data.isEmpty else {
          throw BookPlayerError.runtimeError("The file ended before part \(partNumber)")
        }
        try writer.write(contentsOf: data)
        remaining -= Int64(data.count)
      }
    }
    return partURL
  }

  /// Parts, then the temp hard link (only ever a regular file inside tmp)
  private func removeLocalFiles() {
    try? FileManager.default.removeItem(at: Self.partsDirectory(for: uuid))
    SyncJobScheduler.removeHardLink(at: fileURL)
  }

  static func fileSize(of url: URL) throws -> Int64 {
    let values = try url.resourceValues(forKeys: [.fileSizeKey])
    return Int64(values.fileSize ?? 0)
  }

  static func availableDiskSpace() -> Int64 {
    let url = FileManager.default.temporaryDirectory
#if os(watchOS)
    let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
    return Int64(values?.volumeAvailableCapacity ?? 0)
#else
    let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
    return values?.volumeAvailableCapacityForImportantUsage ?? 0
#endif
  }

  // MARK: - Progress

  /// Reports only when the whole percentage changes: eight parts call back many times a
  /// second, and every report posts to the main thread. Returns the percentage reported.
  private func reportProgress(
    plan: MultipartUploadPlan,
    done: Set<Int>,
    bytesInFlight: [Int: Int64],
    lastReportedPercent: Int
  ) -> Int {
    guard plan.fileSize > 0 else { return lastReportedPercent }
    let sent = done.reduce(Int64(0)) { $0 + plan.size(of: $1) } + bytesInFlight.values.reduce(0, +)
    let progress = min(1, Double(sent) / Double(plan.fileSize))
    let percent = Int(progress * 100)
    guard percent != lastReportedPercent else { return lastReportedPercent }
    onProgress?(progress)
    return percent
  }
}
