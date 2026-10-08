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
  private let connection: NWConnection
  private let stagingDirectory: URL
  private let onFile: (URL) -> Void
  private let onFinished: (ObjectIdentifier) -> Void

  private var buffer = Data()
  private var headersParsed = false
  private var method = ""
  private var path = ""
  private var contentLength: Int?
  private var bodyReceived = 0
  private var fileHandle: FileHandle?
  private var destinationURL: URL?
  private var cancelled = false

  init(
    connection: NWConnection,
    stagingDirectory: URL,
    onFile: @escaping (URL) -> Void,
    onFinished: @escaping (ObjectIdentifier) -> Void
  ) {
    self.connection = connection
    self.stagingDirectory = stagingDirectory
    self.onFile = onFile
    self.onFinished = onFinished
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
      guard let self, !self.cancelled else { return }
      if let error {
        self.failAndClose("Receive error: \(error.localizedDescription)")
        return
      }
      if let data, !data.isEmpty {
        self.handle(data)
      }
      if isComplete {
        if self.headersParsed, self.method == "POST", self.contentLength == nil {
          self.completeUpload()
        } else if !self.headersParsed {
          self.failAndClose("Incomplete request")
        }
        return
      }
      if error == nil {
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
        guard prepareUpload() else { return }
        if !bodyStart.isEmpty {
          appendBody(bodyStart)
        }
        return
      }

      respond(status: 405, body: "Method Not Allowed", contentType: "text/plain; charset=utf-8")
      return
    }

    if method == "POST" {
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

    for line in lines.dropFirst() {
      let lower = line.lowercased()
      if lower.hasPrefix("content-length:") {
        let value = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
        contentLength = Int(value)
      }
    }
    return true
  }

  private func prepareUpload() -> Bool {
    guard path.hasPrefix("/upload") else {
      respond(status: 404, body: "Not Found", contentType: "text/plain; charset=utf-8")
      return false
    }
    guard
      let components = URLComponents(string: path),
      let nameItem = components.queryItems?.first(where: { $0.name == "name" }),
      let rawName = nameItem.value,
      let filename = WifiTransferFileSupport.sanitizedFilename(from: rawName)
    else {
      respond(status: 400, body: "Missing or unsupported file name", contentType: "text/plain; charset=utf-8")
      return false
    }

    let destination = WifiTransferFileSupport.uniqueFileURL(filename: filename, in: stagingDirectory)
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

  private func appendBody(_ data: Data) {
    do {
      try fileHandle?.write(contentsOf: data)
      bodyReceived += data.count
      if let contentLength, bodyReceived >= contentLength {
        completeUpload()
      }
    } catch {
      failAndClose("Write failed")
    }
  }

  private func completeUpload() {
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
    onFile(destinationURL)
    respond(status: 201, body: "OK", contentType: "text/plain; charset=utf-8")
  }

  private func serveHTML() {
    respond(status: 200, body: WifiTransferHTML.page, contentType: "text/html; charset=utf-8")
  }

  private func respond(status: Int, body: String, contentType: String) {
    let reason: String
    switch status {
    case 200: reason = "OK"
    case 201: reason = "Created"
    case 400: reason = "Bad Request"
    case 404: reason = "Not Found"
    case 405: reason = "Method Not Allowed"
    default: reason = "Error"
    }
    let bodyData = Data(body.utf8)
    var response = "HTTP/1.1 \(status) \(reason)\r\n"
    response += "Content-Type: \(contentType)\r\n"
    response += "Content-Length: \(bodyData.count)\r\n"
    response += "Connection: close\r\n"
    response += "Access-Control-Allow-Origin: *\r\n"
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
    if headersParsed, method == "POST", fileHandle != nil || destinationURL != nil {
      try? fileHandle?.close()
      fileHandle = nil
    }
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
    onFinished(ObjectIdentifier(self))
  }
}
