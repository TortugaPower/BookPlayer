//
//  WifiTransferConnection.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import Network

/// Handles one HTTP connection for the Wi‑Fi transfer server.
final class WifiTransferConnection: @unchecked Sendable {
  struct Handlers {
    /// Optional 4-digit PIN; when set, mutating routes require the pin header.
    var pin: String?
    /// Called after a successful top-level (loose) file upload — import immediately.
    var onLooseFile: (URL) -> Void
    /// Import a staged folder (`POST /import?root=`). Must invoke `completion` exactly once.
    var onImportRoot: (_ root: String, _ completion: @escaping (Result<Void, String>) -> Void) -> Void
    var onFinished: (ObjectIdentifier) -> Void
  }

  private let connection: NWConnection
  private let stagingDirectory: URL
  private let handlers: Handlers

  private var buffer = Data()
  private var headersParsed = false
  private var method = ""
  private var path = ""
  private var contentLength: Int?
  private var requestPin: String?
  private var bodyReceived = 0
  private var fileHandle: FileHandle?
  private var destinationURL: URL?
  private var importImmediately = false
  private var cancelled = false
  private var isImportRequest = false
  private var completed = false

  init(
    connection: NWConnection,
    stagingDirectory: URL,
    handlers: Handlers
  ) {
    self.connection = connection
    self.stagingDirectory = stagingDirectory
    self.handlers = handlers
  }

  func start() {
    connection.stateUpdateHandler = { [weak self] state in
      guard let self else { return }
      switch state {
      case .ready:
        self.receive()
      case .failed, .cancelled:
        self.finish()
      default:
        break
      }
    }
    connection.start(queue: .global(qos: .userInitiated))
  }

  func cancel() {
    cancelled = true
    cleanupPartialFile()
    connection.cancel()
  }

  private func receive() {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { [weak self] data, _, isComplete, error in
      guard let self, !self.cancelled, !self.completed else { return }
      if let error {
        self.failAndClose("Receive error: \(error.localizedDescription)")
        return
      }
      if let data, !data.isEmpty {
        self.handle(data)
      }
      if isComplete {
        if self.headersParsed, self.method == "POST", self.isImportRequest {
          // handled in prepareImport (no body)
        } else if self.headersParsed, self.method == "POST", self.contentLength == nil {
          self.completeUpload()
        } else if !self.headersParsed {
          self.failAndClose("Incomplete request")
        }
        return
      }
      if error == nil, !self.completed {
        self.receive()
      }
    }
  }

  private func handle(_ data: Data) {
    if !headersParsed {
      buffer.append(data)
      guard let headerRange = buffer.range(of: Data("\r\n\r\n".utf8)) else {
        if buffer.count > 64 * 1024 {
          failAndClose("Headers too large")
        }
        return
      }
      let headerData = buffer.subdata(in: buffer.startIndex..<headerRange.lowerBound)
      let bodyStart = buffer.subdata(in: headerRange.upperBound..<buffer.endIndex)
      buffer = Data()
      guard parseHeaders(headerData) else { return }
      headersParsed = true

      if method == "GET" {
        serveHTML()
        return
      }

      if method == "POST" {
        guard authorizePinIfNeeded() else { return }
        if path.hasPrefix("/unlock") {
          respond(status: 200, body: "OK", contentType: "text/plain; charset=utf-8")
          return
        }
        if path.hasPrefix("/import") {
          prepareImport()
          return
        }
        if path.hasPrefix("/upload") {
          guard prepareUpload() else { return }
          if !bodyStart.isEmpty {
            appendBody(bodyStart)
          } else if let contentLength, contentLength == 0 {
            completeUpload()
          }
          return
        }
        respond(status: 404, body: "Not Found", contentType: "text/plain; charset=utf-8")
        return
      }

      respond(status: 405, body: "Method Not Allowed", contentType: "text/plain; charset=utf-8")
      return
    }

    if method == "POST", !isImportRequest {
      appendBody(data)
    }
  }

  private func parseHeaders(_ data: Data) -> Bool {
    guard let text = String(data: data, encoding: .utf8) else {
      failAndClose("Invalid headers")
      return false
    }
    let lines = text.split(separator: "\r\n", omittingEmptySubsequences: false)
    guard let requestLine = lines.first else {
      failAndClose("Empty request")
      return false
    }
    let parts = requestLine.split(separator: " ")
    guard parts.count >= 2 else {
      failAndClose("Malformed request line")
      return false
    }
    method = String(parts[0]).uppercased()
    path = String(parts[1])

    let pinHeaderPrefix = WifiTransferFileSupport.pinHeaderName.lowercased() + ":"
    for line in lines.dropFirst() {
      let lower = line.lowercased()
      if lower.hasPrefix("content-length:") {
        let value = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
        contentLength = Int(value)
      } else if lower.hasPrefix(pinHeaderPrefix) {
        requestPin = String(line.dropFirst(pinHeaderPrefix.count))
          .trimmingCharacters(in: .whitespaces)
      }
    }
    return true
  }

  private func authorizePinIfNeeded() -> Bool {
    guard let expected = handlers.pin else { return true }
    guard requestPin == expected else {
      respond(status: 401, body: "Unauthorized", contentType: "text/plain; charset=utf-8")
      return false
    }
    return true
  }

  private func prepareUpload() -> Bool {
    guard let length = contentLength, length > 0 else {
      respond(status: 411, body: "Content-Length required", contentType: "text/plain; charset=utf-8")
      return false
    }
    guard length <= WifiTransferFileSupport.maxUploadBytes else {
      respond(status: 413, body: "File too large", contentType: "text/plain; charset=utf-8")
      return false
    }

    guard
      let components = URLComponents(string: path)
    else {
      respond(status: 400, body: "Bad request", contentType: "text/plain; charset=utf-8")
      return false
    }

    let relative: String?
    if let pathItem = components.queryItems?.first(where: { $0.name == "path" })?.value {
      relative = WifiTransferFileSupport.sanitizedRelativePath(from: pathItem)
    } else if let nameItem = components.queryItems?.first(where: { $0.name == "name" })?.value {
      relative = WifiTransferFileSupport.sanitizedFilename(from: nameItem)
    } else {
      relative = nil
    }

    guard let relative else {
      respond(status: 400, body: "Missing or unsupported file path", contentType: "text/plain; charset=utf-8")
      return false
    }

    guard let destination = WifiTransferFileSupport.uniqueFileURL(relativePath: relative, in: stagingDirectory)
    else {
      respond(status: 500, body: "Could not create file", contentType: "text/plain; charset=utf-8")
      return false
    }

    importImmediately = WifiTransferFileSupport.isLooseFilePath(relative)
    FileManager.default.createFile(atPath: destination.path, contents: nil)
    do {
      fileHandle = try FileHandle(forWritingTo: destination)
      destinationURL = destination
      return true
    } catch {
      respond(status: 500, body: "Could not create file", contentType: "text/plain; charset=utf-8")
      return false
    }
  }

  private func prepareImport() {
    isImportRequest = true
    guard
      let components = URLComponents(string: path),
      let rootItem = components.queryItems?.first(where: { $0.name == "root" })?.value,
      let root = WifiTransferFileSupport.sanitizedRootFolder(from: rootItem)
    else {
      respond(status: 400, body: "Missing or invalid root folder", contentType: "text/plain; charset=utf-8")
      return
    }

    handlers.onImportRoot(root) { [weak self] result in
      guard let self, !self.completed else { return }
      switch result {
      case .success:
        self.respond(status: 200, body: "OK", contentType: "text/plain; charset=utf-8")
      case .failure(let message):
        self.respond(status: 400, body: message, contentType: "text/plain; charset=utf-8")
      }
    }
  }

  private func appendBody(_ data: Data) {
    let nextTotal = bodyReceived + data.count
    if nextTotal > WifiTransferFileSupport.maxUploadBytes {
      cleanupPartialFile()
      respond(status: 413, body: "File too large", contentType: "text/plain; charset=utf-8")
      return
    }
    do {
      try fileHandle?.write(contentsOf: data)
      bodyReceived = nextTotal
      if let contentLength, bodyReceived >= contentLength {
        completeUpload()
      }
    } catch {
      failAndClose("Write failed")
    }
  }

  private func completeUpload() {
    guard !completed else { return }
    try? fileHandle?.close()
    fileHandle = nil
    guard let destinationURL else {
      respond(status: 500, body: "No destination", contentType: "text/plain; charset=utf-8")
      return
    }
    if let contentLength, bodyReceived != contentLength {
      cleanupPartialFile()
      respond(status: 400, body: "Incomplete upload", contentType: "text/plain; charset=utf-8")
      return
    }
    if importImmediately {
      handlers.onLooseFile(destinationURL)
    }
    respond(status: 201, body: "OK", contentType: "text/plain; charset=utf-8")
  }

  private func serveHTML() {
    let html = WifiTransferHTML.page(requiresPin: handlers.pin != nil)
    respond(status: 200, body: html, contentType: "text/html; charset=utf-8")
  }

  private func respond(status: Int, body: String, contentType: String) {
    guard !completed else { return }
    completed = true
    let reason: String
    switch status {
    case 200: reason = "OK"
    case 201: reason = "Created"
    case 400: reason = "Bad Request"
    case 401: reason = "Unauthorized"
    case 404: reason = "Not Found"
    case 405: reason = "Method Not Allowed"
    case 411: reason = "Length Required"
    case 413: reason = "Payload Too Large"
    default: reason = "Error"
    }
    let bodyData = Data(body.utf8)
    var response = "HTTP/1.1 \(status) \(reason)\r\n"
    response += "Content-Type: \(contentType)\r\n"
    response += "Content-Length: \(bodyData.count)\r\n"
    response += "Connection: close\r\n"
    response += "\r\n"
    var payload = Data(response.utf8)
    payload.append(bodyData)
    connection.send(content: payload, completion: .contentProcessed { [weak self] _ in
      self?.connection.cancel()
      self?.finish()
    })
  }

  private func failAndClose(_ message: String) {
    cleanupPartialFile()
    try? fileHandle?.close()
    fileHandle = nil
    if !cancelled {
      respond(status: 400, body: message, contentType: "text/plain; charset=utf-8")
    } else {
      connection.cancel()
      finish()
    }
  }

  private func cleanupPartialFile() {
    try? fileHandle?.close()
    fileHandle = nil
    if let destinationURL {
      try? FileManager.default.removeItem(at: destinationURL)
      self.destinationURL = nil
    }
  }

  private func finish() {
    handlers.onFinished(ObjectIdentifier(self))
  }
}
