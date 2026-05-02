//
//  SortPreferencesResolving.swift
//  BookPlayer
//
//  Protocol for the sticky-sort resolver. Reads/writes per-location
//  sort preferences via UserDefaults, with the App-Group suite as the
//  source of truth.
//

import Foundation

/// Identifies a location within the library that can have a sticky-sort preference.
///
/// Three states, distinguished so callers can't accidentally route a placeholder-UUID
/// folder onto the library-root preference:
///
/// - `.libraryRoot`: the top-level library list. Maps to `library_sort:default`.
/// - `.folder(LibraryItemRef)`: a folder with a real UUID. Maps to `library_sort:<uuid>`.
/// - `.unresolved`: a folder whose UUID is still the placeholder (mid-migration / not synced).
///   Reads return `.custom`; writes are silent no-ops. Distinct from `.libraryRoot`
///   to prevent accidental mutation of the root preference.
public enum SortLocation: Equatable {
  case libraryRoot
  case folder(LibraryItemRef)
  case unresolved
}

/// Reads and writes sticky-sort preferences for a library location.
///
/// Each location is independent — there is no inheritance between the
/// library root and its folders. A location with no stored preference
/// resolves to `.custom`.
public protocol SortPreferencesResolving: AnyObject {
  /// Returns the effective sort for a location.
  ///
  /// - Returns: `.automatic(SortType)` if the location has a stored preference,
  ///   `.custom` otherwise (including for `.unresolved` placeholder-UUID folders).
  func effectiveSort(forLocation location: SortLocation) -> EffectiveSort

  /// Writes the sticky-sort preference for a location.
  ///
  /// No-op when the value matches the currently stored value (idempotent).
  /// Silent no-op for `.unresolved` placeholder-UUID folders.
  func setSort(_ value: EffectiveSort, forLocation location: SortLocation)

  /// Removes any stored override for the location, returning it to `.custom`.
  /// Silent no-op for `.unresolved` placeholder-UUID folders.
  func clearOverride(forLocation location: SortLocation)
}
