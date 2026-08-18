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
  ///
  /// Stored **percent-encoded**. Reading the decoded `URLComponents.path` and re-encoding it cannot
  /// tell an encoded slash from a segment separator, so `/a%2Fb` would silently round-trip to
  /// `/a/b` — a different URL. Keeping the encoded bytes end-to-end makes parse → assemble faithful.
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
    // The *encoded* path, byte-for-byte. (The host, by contrast, is whatever `URLComponents` returns:
    // the parser normalizes Unicode hosts to punycode, which is semantically identical under IDNA and
    // matches what any fresh sign-in stores anyway.)
    self.path = Self.normalizedPath(components.percentEncodedPath)
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
    // `path` is always valid percent-encoding — `normalizedPath` guarantees it — so this cannot trap.
    components.percentEncodedPath = path
    return components.url
  }

  var urlString: String? { url?.absoluteString }

  // MARK: - The combined host field

  /// The host and subpath as one editable string — the design's screen 1 has a single Host row and the
  /// subpath rides in it (`media.example.com/audiobookshelf`).
  ///
  /// This setter is where a paste arrives, so it is where decomposition must happen. Deferring it to
  /// Connect cannot work: splitting a pasted `http://…` at its first slash makes `http:` the host,
  /// and once that's stored the original URL is unrecoverable — the field showed
  /// `[http:]//100.81.227.12:13378` and assembled garbage.
  var hostField: String {
    get { host + path }
    set {
      // A full URL (pasted, or typed through): distribute across ALL the fields — the scheme
      // control flips, the port moves to its row, the host keeps only the host and subpath.
      if newValue.contains("://") {
        if let pasted = IntegrationServerAddress(parsing: newValue) {
          self = pasted
        } else {
          // Mid-typing through the scheme, or an unparseable paste: hold the raw text so nothing
          // is mangled or lost. `url` stays nil (a colon-bearing host never assembles), which
          // keeps Connect disabled until the text resolves into something real.
          host = newValue
          path = ""
        }
        return
      }
      // Scheme-less: peel the subpath off first, then a trailing port off the host part —
      // `host:port` and `host:port/path` are both the mockups' scheme-less paste.
      var rawHost = newValue
      var rawPath = ""
      if let slash = newValue.firstIndex(of: "/") {
        rawHost = String(newValue[..<slash])
        rawPath = String(newValue[slash...])
      }
      // Exactly one colon with a valid port after it can't be an IPv6 literal (those carry two or
      // more colons); a bracketed literal announces its port with `]:`.
      let colonParts = rawHost.split(separator: ":", omittingEmptySubsequences: false)
      if colonParts.count == 2, let pastedPort = Int(colonParts[1]),
         (1...65535).contains(pastedPort), !colonParts[0].isEmpty, !colonParts[0].contains("[") {
        port = pastedPort
        rawHost = String(colonParts[0])
      } else if rawHost.hasPrefix("["), let bracket = rawHost.range(of: "]:"),
                let pastedPort = Int(rawHost[bracket.upperBound...]), (1...65535).contains(pastedPort) {
        port = pastedPort
        rawHost = String(rawHost[..<bracket.upperBound].dropLast())
      }
      host = Self.normalizedHost(rawHost)
      path = Self.normalizedPath(rawPath)
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
  /// `"abs/"`, `"/abs"`, and `"/abs///"` all normalize to `"/abs"`. The result is always valid
  /// percent-encoding: input that already is (a parsed URL, a pasted `/audio%20books`) passes through
  /// byte-for-byte; raw typed text that isn't (`/audio books`) gets encoded once. The distinction is
  /// checked by re-parsing, not guessed at — guessing is how double-encoding bugs happen.
  private static func normalizedPath(_ raw: String) -> String {
    var path = raw
    while path.hasSuffix("/") { path.removeLast() }
    guard !path.isEmpty else { return "" }
    if !path.hasPrefix("/") { path = "/" + path }
    if URLComponents(string: "https://h" + path)?.percentEncodedPath == path {
      return path
    }
    // `?? ""`, not `?? path`: everything this function returns reaches the `percentEncodedPath`
    // setter, which preconditions on valid encoding — an unvalidated fallback is a crash surface.
    // `addingPercentEncoding` failing is practically unreachable for a Swift string, and if it ever
    // happens, assembling without the subpath beats trapping the app over one.
    return path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
  }
}
