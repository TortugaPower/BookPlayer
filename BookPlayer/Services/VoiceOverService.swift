import BookPlayerKit
import Foundation

// MARK: - BookCellView
extension SimpleLibraryItem {
  func getAccessibilityLabel() -> String {
    switch type {
    case .book:
      return String.localizedStringWithFormat(
        "voiceover_book_progress".localized,
        title,
        details,
        percentCompleted,
        durationFormatted
      )
    case .folder:
      return String.localizedStringWithFormat(
        "voiceover_playlist_progress".localized,
        title,
        percentCompleted
      )
    case .bound:
      return String.localizedStringWithFormat(
        "voiceover_bound_books_progress".localized,
        title,
        percentCompleted,
        durationFormatted
      )
    }
  }

}

// MARK: - PlayerMetaView
extension String {
  static func playerMetaText(title: String, author: String) -> String {
    .init(describing: localizedStringWithFormat(
      "voiceover_book_info".localized,
      title,
      author))
  }
}

// MARK: - ArtworkControl
extension PlayerManager {
  static var rewindText: String {
    String(describing: String
      .localizedStringWithFormat(
        "voiceover_rewind_time".localized,
        rewindInterval.rounded().toFormattedHMS()))
  }

  static var fastForwardText: String {
    String(describing: String
      .localizedStringWithFormat(
        "voiceover_forward_time".localized,
        forwardInterval.rounded().toFormattedHMS()))
  }
}

extension TimeInterval {
  func toFormattedHMS() -> String {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .full
    formatter.allowedUnits =  [.hour, .minute, .second]
    return formatter.string(from: self)!
  }
}
