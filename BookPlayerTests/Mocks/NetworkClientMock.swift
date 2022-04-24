//
//  NetworkClientMock.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 23/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation
import BookPlayerKit

class NetworkClientMock: NetworkClientProtocol {
  typealias RawResponse = Decodable
  let mockedResponse: RawResponse

  init(mockedResponse: RawResponse) {
    self.mockedResponse = mockedResponse
  }

  func request<T: RawResponse>(path: String, method: HTTPMethod, parameters: [String: Any]?) async throws -> T {
    // swiftlint:disable:next force_cast
    return self.mockedResponse as! T
  }
}
