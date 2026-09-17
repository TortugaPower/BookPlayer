@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

class VoiceOverServiceTest: XCTestCase {
  override func setUp() {}

  override func tearDown() {}

  func testRewindText() {
    PlayerManager.rewindInterval = 60

    let localizedString = String(describing: String.localizedStringWithFormat("voiceover_rewind_time".localized, VoiceOverService.secondsToMinutes(PlayerManager.rewindInterval.rounded())))

    XCTAssert(VoiceOverService.rewindText() == localizedString)
  }

  func testForwardText() {
    PlayerManager.forwardInterval = 60

    var localizedString = String(describing: String.localizedStringWithFormat("voiceover_forward_time".localized, VoiceOverService.secondsToMinutes(PlayerManager.forwardInterval.rounded())))

    XCTAssert(VoiceOverService.fastForwardText() == localizedString)

    PlayerManager.forwardInterval = 90

    localizedString = String(describing: String.localizedStringWithFormat("voiceover_forward_time".localized, VoiceOverService.secondsToMinutes(PlayerManager.forwardInterval.rounded())))

    XCTAssert(VoiceOverService.fastForwardText() == localizedString)

    PlayerManager.forwardInterval = 120

    localizedString = String(describing: String.localizedStringWithFormat("voiceover_forward_time".localized, VoiceOverService.secondsToMinutes(PlayerManager.forwardInterval.rounded())))

    XCTAssert(VoiceOverService.fastForwardText() == localizedString)
  }

  // MARK: - Media-server source

  private func makeItem(resources: [SimpleExternalResource]?) -> SimpleLibraryItem {
    SimpleLibraryItem(
      title: "CD 01- 001",
      details: "Timothy Ferriss",
      speed: 1,
      currentTime: 0,
      duration: 100,
      percentCompleted: 0,
      isFinished: false,
      relativePath: "cd-01-001.mp3",
      remoteURL: nil,
      artworkURL: nil,
      orderRank: 0,
      parentFolder: nil,
      originalFileName: "cd-01-001.mp3",
      lastPlayDate: nil,
      type: .book,
      uuid: UUID().uuidString,
      externalResources: resources
    )
  }

  private func resource(_ provider: ExternalResource.ProviderName) -> SimpleExternalResource {
    SimpleExternalResource(
      providerName: provider.rawValue,
      providerId: "1",
      syncStatus: ExternalResource.SyncStatus.stream.rawValue,
      lastSyncedAt: nil
    )
  }

  /// The Watch cell draws no provider glyph, so its announcement must not grow one.
  func testAccessibilityLabelOmitsSourceByDefault() {
    let label = VoiceOverService.getAccessibilityLabel(for: makeItem(resources: [resource(.jellyfin)]))

    XCTAssertFalse(label.contains("Jellyfin"), label)
  }

  /// `BookView` draws the glyph ahead of the author, so the name leads the announcement.
  func testAccessibilityLabelLeadsWithMediaServerSource() {
    let label = VoiceOverService.getAccessibilityLabel(
      for: makeItem(resources: [resource(.jellyfin)]),
      includeSource: true
    )

    XCTAssertTrue(label.hasPrefix("Jellyfin, "), label)
  }

  /// `externalResources` comes off an unordered NSSet, so two providers must not swap
  /// between launches.
  func testAccessibilityLabelSourceOrderIsStable() {
    let resources = [resource(.jellyfin), resource(.audiobookshelf)]

    for ordering in [resources, resources.reversed()] {
      let label = VoiceOverService.getAccessibilityLabel(
        for: makeItem(resources: Array(ordering)),
        includeSource: true
      )

      XCTAssertTrue(label.hasPrefix("Audiobookshelf, Jellyfin, "), label)
    }
  }

  /// Hardcover is progress-sync, not a source the book streams from — it earns no glyph in
  /// `BookView`, so it earns no mention here either.
  func testAccessibilityLabelSkipsNonMediaServerSources() {
    let label = VoiceOverService.getAccessibilityLabel(
      for: makeItem(resources: [resource(.hardcover)]),
      includeSource: true
    )

    XCTAssertFalse(label.contains("Hardcover"), label)
    XCTAssertTrue(label.hasPrefix("CD 01- 001"), label)
  }
}
