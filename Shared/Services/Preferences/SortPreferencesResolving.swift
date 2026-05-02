//
//  SortPreferencesResolving.swift
//  BookPlayer
//
//  Protocol for the sticky-sort resolver. Reads/writes per-location
//  sort preferences via UserDefaults, with the App-Group suite as the
//  source of truth.
//

import Foundation

/// Reads and writes sticky-sort preferences for a library location.
///
/// Each location is independent — there is no inheritance between the
/// library root and its folders. A location with no stored preference
/// resolves to `.custom`.
public protocol SortPreferencesResolving: AnyObject {
  /// Returns the effective sort for a location.
  ///
  /// - Parameter location: `nil` for the library root, otherwise the folder ref.
  /// - Returns: `.automatic(SortType)` if the location has a stored preference,
  ///   `.custom` otherwise (including for folders mid-UUID-migration).
  func effectiveSort(forLocation location: LibraryItemRef?) -> EffectiveSort

  /// Writes the sticky-sort preference for a location.
  ///
  /// No-op when the value matches the currently stored value (idempotent).
  /// Silent no-op for folders with placeholder UUIDs.
  func setSort(_ value: EffectiveSort, forLocation location: LibraryItemRef?)

  /// Removes any stored override for the location, returning it to `.custom`.
  /// Silent no-op for folders with placeholder UUIDs.
  func clearOverride(forLocation location: LibraryItemRef?)
}
