//
//  MultipartUploadResponse.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// `POST /v1/library/upload/start`
struct StartUploadResponse: Decodable {
  enum Status: String, Decodable {
    /// A new upload is open: send its parts
    case started
    /// S3 already has the file; the server marked the row synced. Nothing to send.
    case exists
  }

  let status: Status
  let uploadId: String?
  let partSize: Int?
  let partCount: Int?
}

/// `POST /v1/library/upload/parts`
struct UploadPartURLsResponse: Decodable {
  struct Part: Decodable {
    let partNumber: Int
    let url: URL
    /// Unix seconds. An upper bound only: the signing credentials can end the URL sooner.
    let expiresAt: TimeInterval
  }

  let parts: [Part]
}

/// `GET /v1/library/upload/parts`
struct UploadedPartsResponse: Decodable {
  struct Part: Decodable {
    let partNumber: Int
    let size: Int64
  }

  let parts: [Part]
}

/// `POST /v1/library/upload/complete`
struct CompleteUploadResponse: Decodable {
  let synced: Bool
}

/// `POST /v1/library/upload/abort`
struct AbortUploadResponse: Decodable {
  let aborted: Bool
}
