//
//  SecondOnboardingCoordinatorTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// Building the second onboarding's stories when the App Store prices of its products don't all load
/// (BOOKPLAYER-11HV: an empty product lookup used to crash on `.first!`, on every launch).
@MainActor
final class SecondOnboardingCoordinatorTests: XCTestCase {
  private let tier4 = PricingModel(id: PricingOption.supportTier4.rawValue, title: "$3.99", price: 3.99)
  private let tier7 = PricingModel(id: PricingOption.supportTier7.rawValue, title: "$6.99", price: 6.99)
  private let tier10 = PricingModel(id: PricingOption.supportTier10.rawValue, title: "$9.99", price: 9.99)
  private let pro = PricingModel(id: PricingOption.proMonthly.rawValue, title: "$4.99", price: 4.99)

  /// The `first_seen` onboarding as the server sends it: an intro story, then the paywall.
  private var stories: [StoryResponseModel] {
    [
      StoryResponseModel(title: "Intro", body: "Body", image: nil, duration: 5),
      StoryResponseModel(
        title: "Paywall",
        body: "Body",
        image: "image",
        duration: 10,
        action: StoryActionResponseModel(
          options: [tier4.id, tier7.id, tier10.id],
          defaultOption: tier7.id,
          sliderOptions: SliderOptions(min: 3.99, max: 9.99),
          button: "Continue",
          dismiss: "Not now"
        )
      ),
    ]
  }

  func testNoPricesLoadedSkipsTheOnboarding() async {
    let result = await SecondOnboardingCoordinator.parseStoryData(stories) { _ in [] }

    XCTAssertNil(result)
  }

  func testMissingDefaultPriceSkipsTheOnboarding() async {
    let result = await SecondOnboardingCoordinator.parseStoryData(stories) { _ in [tier4, tier10] }

    XCTAssertNil(result)
  }

  func testMissingOptionPriceSkipsTheOnboarding() async {
    let result = await SecondOnboardingCoordinator.parseStoryData(stories) { _ in [tier7, tier10] }

    XCTAssertNil(result)
  }

  func testAllPricesLoadedBuildsTheStories() async throws {
    var requestedIds: [[String]] = []

    let result = await SecondOnboardingCoordinator.parseStoryData(stories) { ids in
      requestedIds.append(ids)
      return [tier10, tier4, tier7]
    }

    let parsed = try XCTUnwrap(result)
    XCTAssertEqual(requestedIds.count, 1)
    XCTAssertEqual(Set(requestedIds.first ?? []), [tier4.id, tier7.id, tier10.id])
    XCTAssertEqual(parsed.map(\.title), ["Intro", "Paywall"])
    XCTAssertNil(parsed[0].action)

    let action = try XCTUnwrap(parsed[1].action)
    XCTAssertEqual(action.options, [tier4, tier7, tier10])
    XCTAssertEqual(action.defaultOption, tier7)
    XCTAssertEqual(action.sliderOptions?.min, 3.99)
    XCTAssertEqual(action.sliderOptions?.max, 9.99)
    XCTAssertEqual(action.button, "Continue")
    XCTAssertEqual(action.dismiss, "Not now")
  }

  /// The `support_paywall` and tips onboardings (most of them on the server) send no options: only the PRO
  /// default, with the tip jar.
  private var paywallWithoutOptions: [StoryResponseModel] {
    [
      StoryResponseModel(
        title: "Paywall",
        body: "Body",
        image: nil,
        duration: 10,
        action: StoryActionResponseModel(
          options: [],
          defaultOption: pro.id,
          button: "Continue for $4.99 / month",
          tipJar: "or open the tip jar",
          tipJarDisclaimer: "Disclaimer"
        )
      )
    ]
  }

  func testPaywallWithoutOptionsNeedsOnlyTheDefaultPrice() async throws {
    var requestedIds: [[String]] = []

    let result = await SecondOnboardingCoordinator.parseStoryData(paywallWithoutOptions) { ids in
      requestedIds.append(ids)
      return [pro]
    }

    let action = try XCTUnwrap(try XCTUnwrap(result).first?.action)
    XCTAssertEqual(requestedIds, [[pro.id]])
    XCTAssertEqual(action.options, [])
    XCTAssertEqual(action.defaultOption, pro)
    XCTAssertEqual(action.tipJar, "or open the tip jar")
    XCTAssertEqual(action.tipJarDisclaimer, "Disclaimer")
  }

  func testPaywallWithoutOptionsSkipsTheOnboardingWithoutTheDefaultPrice() async {
    let result = await SecondOnboardingCoordinator.parseStoryData(paywallWithoutOptions) { _ in [] }

    XCTAssertNil(result)
  }

  func testStoriesWithoutActionsLoadNoPrices() async throws {
    var lookups = 0

    let result = await SecondOnboardingCoordinator.parseStoryData(
      [StoryResponseModel(title: "Intro", body: "Body", image: nil, duration: 5)]
    ) { _ in
      lookups += 1
      return []
    }

    XCTAssertEqual(try XCTUnwrap(result).map(\.title), ["Intro"])
    XCTAssertEqual(lookups, 0)
  }
}
