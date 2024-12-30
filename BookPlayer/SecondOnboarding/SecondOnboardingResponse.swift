//
//  SecondOnboardingResponse.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/7/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation

struct SecondOnboardingResponse: Codable {
  let onboardingId: String
  let type: SecondOnboardingType
  let support: [StoryResponseModel]

  enum CodingKeys: String, CodingKey {
    case type, support
    case onboardingId = "onboarding_id"
  }
}

struct StoryResponseModel: Codable {
  var title: String
  var body: String
  var image: String?
  var duration: TimeInterval
  var action: StoryActionResponseModel?
}

struct StoryActionResponseModel: Codable {
  var options: [String]
  var defaultOption: String
  var sliderOptions: SliderOptions?
  var button: String
  var dismiss: String?

  enum CodingKeys: String, CodingKey {
    case options, button, dismiss
    case defaultOption = "default_option"
    case sliderOptions = "slider_options"
  }
}
