//
//  IntegrationImageSizing.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import CoreGraphics
import Foundation

/// Shared image-URL sizing for media-server integrations (Jellyfin, AudiobookShelf).
///
/// Server image endpoints honour `fillWidth` / `width` query parameters, so the URL
/// changes whenever the SwiftUI cell layout reports a different size. To stop
/// `GeometryReader` jitter from invalidating Kingfisher's cache key, we bucket the
/// pixel size up to a fixed multiple. Non-media cells (folders, libraries, authors,
/// narrators) are additionally capped so they fetch low-resolution thumbnails.
enum IntegrationImageSizing {
  /// Round up to a 64-px multiple — small enough to keep large-screen cells sharp,
  /// large enough that small layout jitter (e.g. 100 → 104 px) doesn't churn the URL.
  static let bucket: CGFloat = 64

  /// Maximum thumbnail edge in pixels. Comfortably sharp for a ~80-pt cell at 3x
  /// (240 px), and much cheaper to encode/transfer than full-resolution covers.
  static let thumbnailCap: CGFloat = 192

  /// Resolve the server-image-URL size query for a cell.
  ///
  /// - Parameters:
  ///   - width: cell width in points.
  ///   - height: cell height in points.
  ///   - displayScale: current `Environment(\.displayScale)` value.
  ///   - isThumbnail: when true, applies `thumbnailCap` so browsing cells stay snappy.
  static func bucketedSize(
    width: CGFloat,
    height: CGFloat,
    displayScale: CGFloat,
    isThumbnail: Bool
  ) -> CGSize {
    let cap: CGFloat = isThumbnail ? thumbnailCap : .greatestFiniteMagnitude
    let pixelWidth = min(max(width, 1) * displayScale, cap)
    let pixelHeight = min(max(height, 1) * displayScale, cap)
    return CGSize(
      width: max(bucket, ceil(pixelWidth / bucket) * bucket),
      height: max(bucket, ceil(pixelHeight / bucket) * bucket)
    )
  }
}
