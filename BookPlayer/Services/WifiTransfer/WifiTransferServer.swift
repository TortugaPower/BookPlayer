//
//  WifiTransferServer.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation
import Network
import UIKit

/// Local HTTP server that accepts audiobook uploads from a browser on the same LAN.
@MainActor
final class WifiTransferServer: ObservableObject, BPLogger {
  enum Status: Equatable {
    case stopped
    case starting
    case running
    case failed(String)
  }

  @Published private(set) var status: Status = .stopped
  @Published private(set) var serverURL: URL?
  @Published private(set) var lastUploadedFilename: String?

  /// Preferred port; falls back through a short range if bound.
  static let preferredPort: UInt16 = 8080
  static let portFallbackCount: UInt16 = 10

  private weak var importManager: ImportManager?
  private var listener: NWListener?
  private var connections: [ObjectIdentifier: WifiTransferConnection] = [:]
  private var backgroundObserver: NSObjectProtocol?

  init() {
    backgroundObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.stop()
      }
    }
  }

  deinit {
    if let backgroundObserver {
      NotificationCenter.default.removeObserver(backgroundObserver)
    }
    listener?.cancel()
  }

  func configure(importManager: ImportManager) {
    self.importManager = importManager
  }

  var isRunning: Bool {
    if case .running = status { return true }
    return false
  }

  var preferredLanguageCode: String {
    Bundle.main.preferredLocalizations.first ?? "en"
  }

  /// - Parameter isOnWiFi: must be true; cellular-only starts are rejected.
  func start(isOnWiFi: Bool) {
    guard !isRunning, status != .starting else { return }
    status = .starting
    serverURL = nil

    guard isOnWiFi else {
      status = .failed("wifi_transfer_no_wifi_message".localized)
      return
    }

    guard let host = Self.localIPv4Address() else {
      status = .failed("wifi_transfer_no_wifi_message".localized)
      return
    }

    tryStart(host: host, portOffset: 0)
  }

  func stop() {
    for connection in connections.values {
      connection.cancel()
    }
    connections.removeAll()
    listener?.cancel()
    listener = nil
    serverURL = nil
    if case .failed = status {
      // keep failure message until next start
    } else {
      status = .stopped
    }
  }

  private func tryStart(host: String, portOffset: UInt16) {
    let portValue = Self.preferredPort + portOffset
    guard let nwPort = NWEndpoint.Port(rawValue: portValue) else {
      status = .failed("wifi_transfer_start_failed_message".localized)
      return
    }

    do {
      let parameters = NWParameters.tcp
      parameters.allowLocalEndpointReuse = true
      let listener = try NWListener(using: parameters, on: nwPort)
      self.listener = listener

      listener.stateUpdateHandler = { [weak self] state in
        Task { @MainActor in
          self?.handleListenerState(state, host: host, port: portValue, portOffset: portOffset)
        }
      }

      listener.newConnectionHandler = { [weak self] connection in
        Task { @MainActor in
          self?.accept(connection)
        }
      }

      listener.start(queue: .main)
    } catch {
      Self.logger.error("Wi‑Fi transfer listener failed: \(error.localizedDescription)")
      if portOffset + 1 < Self.portFallbackCount {
        tryStart(host: host, portOffset: portOffset + 1)
      } else {
        status = .failed("wifi_transfer_start_failed_message".localized)
      }
    }
  }

  private func handleListenerState(
    _ state: NWListener.State,
    host: String,
    port: UInt16,
    portOffset: UInt16
  ) {
    switch state {
    case .ready:
      status = .running
      serverURL = URL(string: "http://\(host):\(port)/")
      Self.logger.info("Wi‑Fi transfer listening on \(host):\(port)")
    case .failed(let error):
      listener?.cancel()
      listener = nil
      Self.logger.error("Wi‑Fi transfer failed: \(error.localizedDescription)")
      if portOffset + 1 < Self.portFallbackCount {
        tryStart(host: host, portOffset: portOffset + 1)
      } else {
        status = .failed("wifi_transfer_start_failed_message".localized)
        serverURL = nil
      }
    case .cancelled:
      if isRunning || status == .starting {
        status = .stopped
        serverURL = nil
      }
    default:
      break
    }
  }

  private func accept(_ connection: NWConnection) {
    let languageCode = preferredLanguageCode
    let handler = WifiTransferConnection(
      connection: connection,
      stagingDirectory: WifiTransferFileSupport.stagingRootURL,
      handlers: WifiTransferConnection.Handlers(
        onLooseFile: { [weak self] url in
          Task { @MainActor in
            self?.handleLooseFile(url)
          }
        },
        onImportRoot: { [weak self] root in
          // Connection I/O runs on a background queue; hop to main and wait.
          var result: Result<Void, String> = .failure("wifi_transfer_import_failed_message".localized)
          let group = DispatchGroup()
          group.enter()
          DispatchQueue.main.async {
            result = self?.importRootFolder(root)
              ?? .failure("wifi_transfer_import_failed_message".localized)
            group.leave()
          }
          _ = group.wait(timeout: .now() + 15)
          return result
        },
        languageCode: languageCode,
        onFinished: { [weak self] id in
          Task { @MainActor in
            self?.connections.removeValue(forKey: id)
          }
        }
      )
    )
    connections[ObjectIdentifier(handler)] = handler
    handler.start()
  }

  private func handleLooseFile(_ stagedURL: URL) {
    do {
      let documents = DataManager.getDocumentsFolderURL()
      let destination = WifiTransferFileSupport.uniqueFileURL(
        filename: stagedURL.lastPathComponent,
        in: documents
      )
      if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
      }
      try FileManager.default.moveItem(at: stagedURL, to: destination)
      lastUploadedFilename = destination.lastPathComponent
      importManager?.process(destination)
    } catch {
      Self.logger.error("Wi‑Fi transfer loose file move failed: \(error.localizedDescription)")
      try? FileManager.default.removeItem(at: stagedURL)
    }
  }

  private func importRootFolder(_ root: String) -> Result<Void, String> {
    guard let root = WifiTransferFileSupport.sanitizedRootFolder(from: root) else {
      return .failure("wifi_transfer_import_failed_message".localized)
    }
    let stagedFolder = WifiTransferFileSupport.stagingRootURL
      .appendingPathComponent(root, isDirectory: true)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: stagedFolder.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      return .failure("wifi_transfer_import_failed_message".localized)
    }

    let documents = DataManager.getDocumentsFolderURL()
    var destination = documents.appendingPathComponent(root, isDirectory: true)
    if FileManager.default.fileExists(atPath: destination.path) {
      var index = 1
      repeat {
        destination = documents.appendingPathComponent("\(root) (\(index))", isDirectory: true)
        index += 1
      } while FileManager.default.fileExists(atPath: destination.path)
    }

    do {
      try FileManager.default.moveItem(at: stagedFolder, to: destination)
      lastUploadedFilename = destination.lastPathComponent
      importManager?.process(destination)
      return .success(())
    } catch {
      Self.logger.error("Wi‑Fi transfer folder import failed: \(error.localizedDescription)")
      return .failure("wifi_transfer_import_failed_message".localized)
    }
  }

  /// IPv4 on the Wi‑Fi interface (`en0`), else first non-loopback IPv4.
  static func localIPv4Address() -> String? {
    var address: String?
    var fallback: String?
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
    defer { freeifaddrs(first) }

    var pointer: UnsafeMutablePointer<ifaddrs>? = first
    while let iface = pointer {
      let flags = Int32(iface.pointee.ifa_flags)
      let isUp = (flags & IFF_UP) != 0
      let isLoopback = (flags & IFF_LOOPBACK) != 0
      if isUp, !isLoopback,
        let addr = iface.pointee.ifa_addr,
        addr.pointee.sa_family == UInt8(AF_INET)
      {
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        getnameinfo(
          addr,
          socklen_t(addr.pointee.sa_len),
          &hostname,
          socklen_t(hostname.count),
          nil,
          0,
          NI_NUMERICHOST
        )
        let ip = String(cString: hostname)
        let name = String(cString: iface.pointee.ifa_name)
        if name == "en0" {
          address = ip
          break
        }
        if fallback == nil {
          fallback = ip
        }
      }
      pointer = iface.pointee.ifa_next
    }
    return address ?? fallback
  }
}
