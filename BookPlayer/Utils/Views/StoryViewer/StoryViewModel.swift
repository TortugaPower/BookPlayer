//
//  StoryViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/6/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation

struct StoryActionType: Codable {
  var options: [PricingOption]
  var defaultOption: PricingOption
  var sliderOptions: SliderOptions?
  var button: String
  var dismiss: String?
  
  enum CodingKeys: String, CodingKey {
    case options, button, dismiss
    case defaultOption = "default_option"
    case sliderOptions = "slider_options"
  }
}

struct SliderOptions: Codable {
  var min: Double
  var max: Double
}

struct StoryViewModel: Identifiable, Equatable, Codable {
  static func == (lhs: StoryViewModel, rhs: StoryViewModel) -> Bool {
    lhs.id == rhs.id
  }

  var id: String { title }
  var title: String
  var body: String
  var image: String?
  var duration: TimeInterval
  var action: StoryActionType?
}
