//
//  URLSession+BookPlayer.swift
//  BookPlayer
//
//  Created by gianni.carlo on 23/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

extension URLSession {
  func data(for request: URLRequest) async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
      let task = self.dataTask(with: request) { data, _, error in
        guard let data = data else {
          let error = error ?? URLError(.badServerResponse)
          return continuation.resume(throwing: error)
        }

        continuation.resume(returning: data)
      }

      task.resume()
    }
  }
}
