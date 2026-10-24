//
//  TransferViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 17/10/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import BrowserDrop
import Foundation
import UIKit

/// Runs a BrowserDrop session while the Transfer sheet is up. A computer on the same network opens the
/// address shown and uploads files, which wait in staging and are listed like an import.
///
/// Done hands them straight to an `ImportOperation`, the same step the import screen's own Done takes, so
/// the import screen never opens and the library goes on to its placement prompt. Cancel, or closing the
/// app, throws them away.
@MainActor
final class TransferViewModel: ObservableObject, BPLogger {
  enum Status: Equatable {
    case starting
    case running
  }

  /// What the browser may send: the file picker's audio, movie and zip types, by extension, since the page
  /// filters before uploading.
  static let acceptedExtensions: Set<String> = [
    "mp3", "m4a", "m4b", "aac", "aax", "aaxc", "wav", "aif", "aiff", "caf", "flac", "opus", "ogg", "oga",
    "mp4", "m4v", "mov", "avi", "zip", "lpf",
  ]

  /// Where Done moves the received files for the import to take. The import owns each folder in it and
  /// deletes it when done; what a killed app leaves behind goes at launch (``removeLeftovers()``).
  static let holdingRoot = FileManager.default.temporaryDirectory
    .appendingPathComponent("TransferImport", isDirectory: true)

  @Published private(set) var status = Status.starting
  /// The address to show, best first; nil until listening, or when this device has no network to share.
  @Published private(set) var address: BrowserDropServer.Address?
  @Published private(set) var receivedFiles: [BrowserDropServer.ReceivedFile] = []

  private let importManager: ImportManager
  private let libraryService: LibraryServiceProtocol
  /// Internal for tests, which read the bound port from its state.
  let server: BrowserDropServer
  private var eventsTask: Task<Void, Never>?
  /// Session work runs in order: a removal finishes before Done takes the files, and a quick
  /// background-and-back suspends before it resumes.
  private var lastSessionTask: Task<Void, Never>?
  private var hasStarted = false
  private var hasEnded = false
  private var previousIdleTimerDisabled: Bool?

  /// `configuration` is for tests (any port, their own staging); the app uses the default.
  init(
    importManager: ImportManager,
    libraryService: LibraryServiceProtocol,
    configuration: BrowserDropServer.Configuration? = nil
  ) {
    self.importManager = importManager
    self.libraryService = libraryService
    self.server = BrowserDropServer(
      configuration: configuration
        ?? .init(
          // Port 80 keeps the address short; then 8080, then any free port, so listening practically
          // never fails (the address shows the port when it isn't 80).
          ports: [80, 8080, 0],
          allowedExtensions: Self.acceptedExtensions,
          pageSettings: Self.pageSettings()
        )
    )
  }

  /// Staging left by a session or an import the app never finished (a crash or a force-quit).
  static func removeLeftovers() {
    BrowserDropServer.removeLeftovers()
    try? FileManager.default.removeItem(at: holdingRoot)
  }

  /// What the import list shows: each file at the top, and each folder with how many files it holds.
  var rows: [ImportConfirmationRow] {
    Self.rows(forRelativePaths: receivedFiles.map(\.relativePath))
  }

  /// Files the list's header counts, inside folders too.
  var fileCount: Int { receivedFiles.count }

  /// Rows for the received files' relative paths: a file at the top is its own row, and a file in a
  /// folder counts toward that folder's row. Files come first, then folders in the order first seen;
  /// the shell sorts them by title for display. A row's id is the path ``remove(_:)`` hands to
  /// BrowserDrop.
  static func rows(forRelativePaths paths: [String]) -> [ImportConfirmationRow] {
    var rows: [ImportConfirmationRow] = []
    var folders: [String] = []
    var folderCounts: [String: Int] = [:]
    for path in paths {
      let parts = path.split(separator: "/", maxSplits: 1)
      if parts.count == 2 {
        let folder = String(parts[0])
        if folderCounts[folder] == nil { folders.append(folder) }
        folderCounts[folder, default: 0] += 1
      } else {
        rows.append(ImportConfirmationRow(id: path, icon: "waveform", title: path))
      }
    }
    for folder in folders {
      rows.append(
        ImportConfirmationRow(
          id: folder,
          icon: "folder",
          title: folder,
          subtitle: String.localizedStringWithFormat("files_title".localized, folderCounts[folder] ?? 0)
        )
      )
    }
    return rows
  }

  // MARK: - Sheet

  /// The sheet appeared: start listening.
  func start() {
    guard !hasStarted else { return }
    hasStarted = true
    keepScreenAwake()

    let server = server
    eventsTask = Task { [weak self] in
      for await event in server.events {
        self?.handle(event)
      }
    }
    listen()
  }

  /// iOS suspends apps in the background, so the server stops listening there. Files that arrived stay.
  func appEnteredBackground() {
    guard hasStarted, !hasEnded else { return }
    let server = server
    runInOrder { await server.suspend() }
  }

  /// Back from the background: listen again on the same port, so the open browser tab carries on.
  func appWillEnterForeground() {
    guard hasStarted, !hasEnded else { return }
    listen()
  }

  func copyAddress() {
    guard let address else { return }
    UIPasteboard.general.string = address.url.absoluteString
  }

  /// A row's ⊖: drop that file, or that folder and its files, from what Done imports.
  func remove(_ rowID: ImportConfirmationRow.ID) {
    let server = server
    runInOrder { [weak self] in
      do {
        try await server.removeReceivedItem(at: rowID)
      } catch {
        Self.logger.error("Transfer couldn't remove \(rowID): \(error.localizedDescription)")
      }
      self?.receivedFiles = await server.receivedFiles
    }
  }

  /// Done: hand what arrived to the import. It runs on its own, so the sheet can close right away; the
  /// library's placement prompt waits for the sheet's cover to go.
  func confirm() {
    guard end() else { return }
    let server = server
    let importManager = importManager
    let libraryService = libraryService
    runInOrder {
      let holding = Self.holdingRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
      var items: [URL] = []
      do {
        try FileManager.default.createDirectory(at: holding, withIntermediateDirectories: true)
        items = try await server.finish(movingInto: holding)
      } catch BrowserDropError.couldNotMove(let moved, let failed) {
        Self.logger.error("Transfer couldn't hand over \(failed.count) items")
        items = moved
      } catch {
        Self.logger.error("Transfer couldn't hand over its files: \(error.localizedDescription)")
      }
      guard !items.isEmpty else {
        try? FileManager.default.removeItem(at: holding)
        return
      }
      importManager.operationPublisher.send(
        ImportOperation(files: items, libraryService: libraryService, ownedSourceRoot: holding)
      )
    }
  }

  /// Cancel: throw away what arrived.
  func discard() {
    guard end() else { return }
    let server = server
    runInOrder { await server.cancel() }
  }

  /// The sheet is gone. It can't be swiped away, so this only ends a session that Done or Cancel didn't.
  func sheetDisappeared() {
    discard()
  }

  // MARK: - Session

  /// Marks the session over, once. Returns false if it already was.
  private func end() -> Bool {
    guard !hasEnded else { return false }
    hasEnded = true
    restoreIdleTimer()
    eventsTask?.cancel()
    return true
  }

  /// Starts the session the first time, and listens again after the background or an interruption,
  /// keeping what arrived.
  private func listen() {
    let server = server
    runInOrder { [weak self] in
      do {
        let addresses: [BrowserDropServer.Address]
        if await server.state == .idle {
          addresses = try await server.start()
        } else {
          addresses = try await server.resume()
        }
        self?.address = addresses.first
        self?.status = .running
      } catch {
        // Nothing on screen: the browser can't reach the address, and coming back to the app tries
        // again. A first start that fails keeps the spinner.
        Self.logger.error("Transfer couldn't listen: \(error.localizedDescription)")
      }
    }
  }

  private func runInOrder(_ operation: @escaping @MainActor () async -> Void) {
    let previous = lastSessionTask
    lastSessionTask = Task {
      await previous?.value
      await operation()
    }
  }

  private func handle(_ event: BrowserDropServer.Event) {
    switch event {
    case .uploadFinished(let file):
      // Uploading a path again replaces it.
      if let index = receivedFiles.firstIndex(where: { $0.relativePath == file.relativePath }) {
        receivedFiles[index] = file
      } else {
        receivedFiles.append(file)
      }
    case .addressesChanged(let addresses):
      address = addresses.first
    case .interrupted:
      // In the background, coming back resumes it. Inactive (Control Center over the sheet) isn't the
      // background: coming back from it doesn't send willEnterForeground, so resume now.
      if UIApplication.shared.applicationState != .background {
        listen()
      }
    case .uploadStarted, .uploadProgress, .uploadFailed:
      // The browser shows progress and failures; the list here holds what's ready to import.
      break
    }
  }

  /// Locking the phone mid-upload would suspend the app and stop the upload, so the screen stays on while
  /// the sheet is up. The player also sets this, so the previous value is restored rather than cleared.
  private func keepScreenAwake() {
    guard previousIdleTimerDisabled == nil else { return }
    previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
    UIApplication.shared.isIdleTimerDisabled = true
  }

  private func restoreIdleTimer() {
    guard let previous = previousIdleTimerDisabled else { return }
    UIApplication.shared.isIdleTimerDisabled = previous
    previousIdleTimerDisabled = nil
  }

  // MARK: - Page

  /// The upload page's title, color and text, in the app's language.
  private static func pageSettings() -> BrowserDropServer.PageSettings {
    let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "BookPlayer"
    return BrowserDropServer.PageSettings(
      title: appName,
      language: Bundle.main.preferredLocalizations.first,
      accentColor: hex(ThemeManager.shared.currentTheme.linkColor),
      strings: [
        "subtitle": "transfer_server_web_subtitle".localized,
        "dropTitle": "transfer_server_web_drop_title".localized,
        "dropHint": "transfer_server_web_folder_hint".localized,
        "chooseFiles": "transfer_server_web_choose_files".localized,
        "chooseFolder": "transfer_server_web_choose_folder".localized,
        "retry": "transfer_server_web_retry".localized,
        "uploading": "transfer_server_web_uploading".localized,
        "uploaded": "transfer_server_web_uploaded".localized,
        "failed": "transfer_server_web_failed".localized,
        "summaryEmpty": "transfer_server_web_queue_empty".localized,
        "skipped": "transfer_server_web_skipped".localized.replacingOccurrences(of: "%d", with: "{count}"),
        "queued": "transfer_web_queued".localized,
        "summary": "transfer_web_summary".localized
          .replacingOccurrences(of: "%1$d", with: "{done}")
          .replacingOccurrences(of: "%2$d", with: "{total}"),
        "waitingForDevice": "transfer_web_waiting".localized,
        "deviceUnreachable": "transfer_web_unreachable".localized,
        "notEnoughSpace": "transfer_web_not_enough_space".localized,
        "tooLarge": "transfer_web_too_large".localized,
        "unsupported": "transfer_web_unsupported".localized,
        "doneHint": "transfer_web_done_hint".localized,
        "loadError": "transfer_web_load_error".localized,
      ]
    )
  }

  private static func hex(_ color: UIColor) -> String? {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    guard color.getRed(&red, green: &green, blue: &blue, alpha: nil) else { return nil }
    let channel = { (value: CGFloat) in Int((min(max(value, 0), 1) * 255).rounded()) }
    return String(format: "#%02X%02X%02X", channel(red), channel(green), channel(blue))
  }
}
