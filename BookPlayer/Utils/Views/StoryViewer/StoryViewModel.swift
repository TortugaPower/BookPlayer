//
//  StoryViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/6/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

struct StoryActionType: Codable {
  var options: [PricingModel]
  var defaultOption: PricingModel
  var sliderOptions: SliderOptions?
  var button: String
  var dismiss: String?
  var tipJar: String?
  var tipJarDisclaimer: String?

  enum CodingKeys: String, CodingKey {
    case options, button, dismiss
    case tipJar = "tip_jar"
    case tipJarDisclaimer = "tip_jar_disclaimer"
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
