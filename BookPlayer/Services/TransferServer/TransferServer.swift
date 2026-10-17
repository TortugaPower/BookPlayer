//
//  TransferServer.swift
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
final class TransferServer: ObservableObject, BPLogger {
  enum Status: Equatable {
    case stopped
    case starting
    case running
    case failed(String)
  }

  @Published private(set) var status: Status = .stopped
  @Published private(set) var serverURL: URL?
  @Published private(set) var lastUploadedFilename: String?

  /// Default preferred port when the user has not customized it.
  static let preferredPort: UInt16 = TransferServerSupport.defaultPort
  static let portFallbackCount: UInt16 = 10

  private weak var importManager: ImportManager?
  private var listener: NWListener?
  private var connections: [ObjectIdentifier: TransferServerConnection] = [:]
  private var backgroundObserver: NSObjectProtocol?
  /// Optional 4-digit PIN for this session (`nil` = open while screen is active).
  private var sessionPin: String?
  private var basePort: UInt16 = TransferServerSupport.defaultPort

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

  func start() {
    guard !isRunning, status != .starting else { return }
    status = .starting
    serverURL = nil
    basePort = TransferServerSupport.Preferences.port
    sessionPin = TransferServerSupport.Preferences.pin
    // Drop any orphaned staging from a previous crashed / aborted session.
    TransferServerSupport.clearStagingDirectory()

    tryStart(host: Self.localIPv4Address(), portOffset: 0)
  }

  func stop() {
    for connection in connections.values {
      connection.cancel()
    }
    connections.removeAll()
    listener?.cancel()
    listener = nil
    serverURL = nil
    sessionPin = nil
    // Cancel closes in-flight writes; wipe the rest so partial folder trees do not linger.
    TransferServerSupport.clearStagingDirectory()
    status = .stopped
  }

  private func tryStart(host: String, portOffset: UInt16) {
    let portValue = basePort + portOffset
    guard portValue >= basePort,
      let nwPort = NWEndpoint.Port(rawValue: portValue)
    else {
      status = .failed("transfer_server_start_failed_message".localized)
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
      Self.logger.error("Transfer server listener failed: \(error.localizedDescription)")
      if portOffset + 1 < Self.portFallbackCount {
        tryStart(host: host, portOffset: portOffset + 1)
      } else {
        sessionPin = nil
        status = .failed("transfer_server_start_failed_message".localized)
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
      Self.logger.info("Transfer server listening on \(host):\(port)")
    case .failed(let error):
      listener?.cancel()
      listener = nil
      Self.logger.error("Transfer server failed: \(error.localizedDescription)")
      if portOffset + 1 < Self.portFallbackCount {
        tryStart(host: host, portOffset: portOffset + 1)
      } else {
        status = .failed("transfer_server_start_failed_message".localized)
        serverURL = nil
        sessionPin = nil
      }
    case .cancelled:
      if isRunning || status == .starting {
        status = .stopped
        serverURL = nil
        sessionPin = nil
      }
    default:
      break
    }
  }

  private func accept(_ connection: NWConnection) {
    let handler = TransferServerConnection(
      connection: connection,
      stagingDirectory: TransferServerSupport.stagingRootURL,
      handlers: TransferServerConnection.Handlers(
        pin: sessionPin,
        onLooseFile: { [weak self] url in
          Task { @MainActor in
            self?.handleLooseFile(url)
          }
        },
        onImportRoot: { [weak self] root, completion in
          Task { @MainActor in
            let result = self?.importRootFolder(root)
              ?? .failure("transfer_server_import_failed_message".localized)
            completion(result)
          }
        },
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
      let destination = TransferServerSupport.uniqueFileURL(
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
      Self.logger.error("Transfer server loose file move failed: \(error.localizedDescription)")
      try? FileManager.default.removeItem(at: stagedURL)
    }
  }

  private func importRootFolder(_ root: String) -> Result<Void, String> {
    guard let root = TransferServerSupport.sanitizedRootFolder(from: root) else {
      return .failure("transfer_server_import_failed_message".localized)
    }
    let stagedFolder = TransferServerSupport.stagingRootURL
      .appendingPathComponent(root, isDirectory: true)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: stagedFolder.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      return .failure("transfer_server_import_failed_message".localized)
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
      Self.logger.error("Transfer server folder import failed: \(error.localizedDescription)")
      // Leave nothing half-moved under staging if import cannot proceed.
      try? FileManager.default.removeItem(at: stagedFolder)
      return .failure("transfer_server_import_failed_message".localized)
    }
  }

  /// Best LAN IPv4 for the share URL (`en0` preferred). Falls back to loopback so
  /// the server can still start on Simulator / local-only setups.
  static func localIPv4Address() -> String {
    var address: String?
    var fallback: String?
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return "127.0.0.1" }
    defer { freeifaddrs(first) }

    var pointer: UnsafeMutablePointer<ifaddrs>? = first
    while let iface = pointer {
      let flags = Int32(iface.pointee.ifa_flags)
      let isUp = (flags & IFF_UP) != 0
      let isLoopback = (flags & IFF_LOOPBACK) != 0
      if isUp,
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
        if !isLoopback, name == "en0" {
          address = ip
          break
        }
        if !isLoopback, fallback == nil {
          fallback = ip
        }
      }
      pointer = iface.pointee.ifa_next
    }
    return address ?? fallback ?? "127.0.0.1"
  }
}
