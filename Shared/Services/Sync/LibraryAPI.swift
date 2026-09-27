//
//  LibraryAPI.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 24/4/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import Foundation

public enum LibraryAPI {
  case syncedIdentifiers
  case contents(path: String)
  case upload(params: [String: Any])
  case externalResource(params: [String: Any])
  case update(params: [String: Any])
  case move(origin: String, destination: String, uuid: String)
  case renameFolder(path: String, name: String, uuid: String)
  case remoteFileURL(path: String, uuid: String?)
  case remoteContentsURL(path: String, uuid: String?)
  case delete(path: String, uuid: String)
  case shallowDelete(path: String, uuid: String)
  case bookmarks(path: String, uuid: String?)
  case setBookmark(path: String, note: String?, time: Double, isActive: Bool, uuid: String)
  case uploadArtwork(path: String, filename: String, uploaded: Bool?, uuid: String)
  case matchUuids(uuidsDictionary: [String: String])
  case externalResourceToDownload(uuid: String, uploaded: Bool)
  case deleteExternalResource(uuid: String, providerName: String, providerId: String)
  /// Multipart upload of a book's file (bookplayer-api docs/multipart-uploads.md). Every
  /// call names the book by uuid; the server derives the S3 key. Call `startUpload` only
  /// without an `uploadId` — it aborts any upload still open for the book.
  case startUpload(uuid: String, fileSize: Int64, partSize: Int)
  /// Presigned URLs for up to 32 parts
  case uploadPartURLs(uuid: String, uploadId: String, partNumbers: [Int])
  /// The parts S3 already holds — the source of truth for resuming
  case uploadedParts(uuid: String, uploadId: String)
  /// Assembles the file; the server sets `synced` (and marks media-server resources
  /// downloaded). Safe to repeat.
  case completeUpload(uuid: String, uploadId: String, partCount: Int, fileSize: Int64)
  case abortUpload(uuid: String, uploadId: String)
}

extension LibraryAPI: Endpoint {
  public var path: String {
    switch self {
    case .syncedIdentifiers:
      return "/v1/library/keys"
    case .contents:
      return "/v1/library"
    case .upload:
      return "/v1/library"
    case .update:
      return "/v1/library"
    case .move:
      return "/v1/library/move"
    case .renameFolder:
      return "/v1/library/rename"
    case .remoteFileURL:
      return "/v1/library"
    case .remoteContentsURL:
      return "/v1/library"
    case .delete:
      return "/v1/library"
    case .shallowDelete:
      return "/v1/library/folder_in_out"
    case .bookmarks:
      return "/v1/library/bookmarks"
    case .setBookmark:
      return "/v1/library/bookmark"
    case .uploadArtwork:
      return "/v1/library/thumbnail_set"
    case .matchUuids:
      return "/v1/library/uuids"
    case .externalResource:
      return "/v1/library/external"
    case .externalResourceToDownload:
      return "/v1/library/external_set"
    case .deleteExternalResource:
      return "/v1/library/external"
    case .startUpload:
      return "/v1/library/upload/start"
    case .uploadPartURLs, .uploadedParts:
      return "/v1/library/upload/parts"
    case .completeUpload:
      return "/v1/library/upload/complete"
    case .abortUpload:
      return "/v1/library/upload/abort"
    }
  }

  public var method: HTTPMethod {
    switch self {
    case .syncedIdentifiers:
      return .get
    case .contents:
      return .get
    case .upload:
      return .put
    case .update:
      return .post
    case .move:
      return .post
    case .renameFolder:
      return .post
    case .remoteFileURL:
      return .get
    case .remoteContentsURL:
      return .get
    case .delete:
      return .delete
    case .shallowDelete:
      return .delete
    case .bookmarks:
      return .get
    case .setBookmark:
      return .put
    case .uploadArtwork:
      return .post
    case .matchUuids:
      return .post
    case .externalResource:
      return .put
    case .externalResourceToDownload:
      return .post
    case .deleteExternalResource:
      return .delete
    case .startUpload, .uploadPartURLs, .completeUpload, .abortUpload:
      return .post
    case .uploadedParts:
      return .get
    }
  }

  public var parameters: [String: Any]? {
    switch self {
    case .syncedIdentifiers:
      return nil
    case .contents(let path):
      return [
        "relativePath": path,
        "sign": true
      ]
    case .upload(let params):
      return params
    case .update(let params):
      return params
    case .move(let origin, let destination, let uuid):
      return [
        "origin": origin,
        "destination": destination,
        "uuid": uuid
      ]
    case .renameFolder(let path, let name, let uuid):
      return [
        "relativePath": path,
        "newName": name,
        "uuid": uuid
      ]
    case .remoteFileURL(let path, let uuid):
      return [
        "relativePath": path,
        "sign": true,
        "uuid": uuid as Any
      ]
    case .remoteContentsURL(let path, let uuid):
      // `uuid` names the container; the trailing slash asks the API for its
      // children, listed by the container's server-side key — so the listing is
      // right even when this device still holds a pre-rename path. Requires the
      // API contract shipped in bookplayer-api#49. (Until the GET encoder fix in
      // NetworkClient, this uuid reached the server as `Optional("…")` and was
      // silently ignored, so the path did all the work.)
      return [
        "relativePath": "\(path)/",
        "sign": true,
        "uuid": uuid as Any
      ]
    case .delete(let path, let uuid):
      return ["relativePath": path, "uuid": uuid]
    case .shallowDelete(let path, let uuid):
      return ["relativePath": path, "uuid": uuid]
    case .bookmarks(let path, let uuid):
      return ["relativePath": path, "uuid": uuid as Any]
    case .setBookmark(let path, let note, let time, let isActive, let uuid):
      var params: [String: Any] = [
        "key": path,
        "time": time,
        "active": isActive,
        "uuid": uuid
      ]

      if let note {
        params["note"] = note
      }

      return params
    case .uploadArtwork(let path, let filename, let uploaded, let uuid):
      var params: [String: Any] = [
        "relativePath": path,
        "thumbnail_name": filename,
        "uuid": uuid
      ]

      if let uploaded {
        params["uploaded"] = uploaded
      }

      return params
    case .matchUuids(let uuidsDictionary):
      return [
        "items": uuidsDictionary
      ]
    case .externalResource(let params):
      return params
    case .externalResourceToDownload(let uuid, let uploaded):
      return [
        "uuid": uuid,
        "uploaded": uploaded
      ]
    case .deleteExternalResource(let uuid, let providerName, let providerId):
      return [
        "uuid": uuid,
        "providerName": providerName,
        "providerId": providerId
      ]
    case .startUpload(let uuid, let fileSize, let partSize):
      return ["uuid": uuid, "fileSize": fileSize, "partSize": partSize]
    case .uploadPartURLs(let uuid, let uploadId, let partNumbers):
      return ["uuid": uuid, "uploadId": uploadId, "partNumbers": partNumbers]
    case .uploadedParts(let uuid, let uploadId):
      return ["uuid": uuid, "uploadId": uploadId]
    case .completeUpload(let uuid, let uploadId, let partCount, let fileSize):
      return ["uuid": uuid, "uploadId": uploadId, "partCount": partCount, "fileSize": fileSize]
    case .abortUpload(let uuid, let uploadId):
      return ["uuid": uuid, "uploadId": uploadId]
    }
  }
}
