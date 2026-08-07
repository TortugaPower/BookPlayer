//
//  IntegrationServerAddress.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 8/8/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// A media-server address as the connection form edits it: an explicit scheme choice, a host that may
/// carry a reverse-proxy subpath, and an optional port.
///
/// This is a *form-level* model. Persistence is untouched — `JellyfinConnectionData` /
/// `AudiobookShelfConnectionData` keep storing a single `URL`, and this type only parses that URL into
/// editable fields and assembles the fields back. Changing the stored shape would sign users out;
/// deriving instead is the same trick `IntegrationConnectionPayload.token` uses.
///
/// Two rules from the connection-screen design are load-bearing here:
/// - **The URL is assembled strictly from typed input.** An empty port produces no port at all — the
///   scheme's own default applies, exactly as in a browser. Nothing is substituted from a placeholder.
/// - **Only `http` and `https` exist.** `init(parsing:)` rejects everything else, so a stored or pasted
///   `javascript:`/`file:` address can never round-trip into a connectable value.
struct IntegrationServerAddress: Equatable, Sendable {
  enum Scheme: String, CaseIterable, Equatable, Sendable {
    case http
    case https
  }

  var scheme: Scheme

  /// Hostname or IP literal, without port or path. IPv6 literals are stored *with* their brackets
  /// (`"[::1]"`) — that is the form `URLComponents` both produces on parse and requires for assembly
  /// on this Foundation, and it is how users type them anyway. May be empty while the user is typing;
  /// `url` returns nil until it isn't.
  var host: String

  /// Normalized subpath: either empty or leading-slash with no trailing slash (`"/audiobookshelf"`).
  /// AudiobookShelf behind a reverse proxy on a subpath is common enough that dropping this would
  /// strand those installs.
  var path: String

  /// Nil means "not specified" — never a default filled in on the user's behalf.
  var port: Int?

  init(scheme: Scheme, host: String, path: String = "", port: Int? = nil) {
    self.scheme = scheme
    self.host = Self.normalizedHost(host)
    self.path = Self.normalizedPath(path)
    self.port = port
  }

  // MARK: - Parsing

  /// Decomposes a full URL string — a stored connection URL, or a paste from a browser.
  ///
  /// Accepts only what the connection flow can use: an explicit `http`/`https` scheme and a host.
  /// Userinfo, query, and fragment components mean the string is not a server base URL, so they are
  /// rejected rather than silently dropped — a paste that loses pieces without saying so would
  /// misconnect quietly.
  init?(parsing string: String) {
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    guard
      let components = URLComponents(string: trimmed),
      let rawScheme = components.scheme,
      let scheme = Scheme(rawValue: rawScheme.lowercased()),
      let host = components.host,
      !host.isEmpty,
      components.user == nil,
      components.password == nil,
      components.query == nil,
      components.fragment == nil
    else { return nil }

    if let port = components.port {
      guard (1...65535).contains(port) else { return nil }
      self.port = port
    } else {
      self.port = nil
    }

    self.scheme = scheme
    self.host = host
    self.path = Self.normalizedPath(components.path)
  }

  // MARK: - Assembly

  /// The address as a connectable URL, built strictly from the fields. Nil while the host is empty.
  ///
  /// Assembled through `URLComponents` rather than string concatenation so IPv6 literals get their
  /// brackets back and a path that needs percent-encoding gets it.
  var url: URL? {
    guard !host.isEmpty else { return nil }
    var components = URLComponents()
    components.scheme = scheme.rawValue
    components.host = host
    components.port = port
    components.path = path
    return components.url
  }

  var urlString: String? { url?.absoluteString }

  // MARK: - The combined host field

  /// The host and subpath as one editable string — the design's screen 1 has a single Host row and the
  /// subpath rides in it (`media.example.com/audiobookshelf`). The setter splits at the first slash;
  /// IPv6 brackets are safe because they cannot contain one.
  var hostField: String {
    get { host + path }
    set {
      if let slash = newValue.firstIndex(of: "/") {
        host = Self.normalizedHost(String(newValue[..<slash]))
        path = Self.normalizedPath(String(newValue[slash...]))
      } else {
        host = Self.normalizedHost(newValue)
        path = ""
      }
    }
  }

  // MARK: - Helpers

  /// A bare IPv6 literal gains its brackets: `URLComponents` refuses to assemble a host containing
  /// a colon without them, so a bare `"::1"` would make `url` silently nil. No other legitimate host
  /// contains a colon — ports live in their own field — so the wrap cannot misfire.
  private static func normalizedHost(_ raw: String) -> String {
    guard raw.contains(":"), !raw.hasPrefix("[") else { return raw }
    return "[" + raw + "]"
  }

  /// Empty stays empty; anything else gains a leading slash and loses trailing ones, so
  /// `"abs/"`, `"/abs"`, and `"/abs///"` all normalize to `"/abs"`.
  private static func normalizedPath(_ raw: String) -> String {
    var path = raw
    while path.hasSuffix("/") { path.removeLast() }
    guard !path.isEmpty else { return "" }
    return path.hasPrefix("/") ? path : "/" + path
  }
}
