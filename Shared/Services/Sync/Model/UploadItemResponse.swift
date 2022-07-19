//
//  UploadItemResponse.swift
//  BookPlayer
//
//  Created by gianni.carlo on 9/7/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

struct UploadItemResponse: Decodable {
  let content: UploadItemContent
}

struct UploadItemContent: Decodable {
  let url: String?
}
