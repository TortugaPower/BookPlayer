//
//  HardcoverAudiobookEditionsData.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/27/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

struct HardcoverAudiobookEditionsData: Codable {
  let editions: [Edition]

  struct Edition: Codable {
    let id: String
    let title: String
    let asin: String?
    let audioSeconds: Int?

    enum CodingKeys: String, CodingKey {
      case id, title, asin
      case audioSeconds = "audio_seconds"
    }
  }
}
