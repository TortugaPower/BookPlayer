//
//  SecondOnboardingResponse.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/7/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import Foundation

struct SecondOnboardingResponse: Codable {
  let onboardingId: String
  let type: SecondOnboardingType
  let support: [StoryViewModel]

  enum CodingKeys: String, CodingKey {
    case type, support
    case onboardingId = "onboarding_id"
  }
}
