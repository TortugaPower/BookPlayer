#if os(watchOS)
  import BookPlayerWatchKit
#else
  import BookPlayerKit
#endif
import Foundation

class VoiceOverService {
  // MARK: - BookCellView

  /// - Parameter useOriginalFileName: When true, the announcement uses
  ///   the imported filename (matching what `BookView` renders under the
  ///   library display preference). Defaults to false so non-library
  ///   callers (Watch, etc.) keep their current behavior.
  /// - Parameter includeSource: When true, the announcement names the media servers the item
  ///   is linked to. `BookView` draws those as bare glyphs and the row is a single
  ///   accessibility element, so this is the only way that provenance reaches VoiceOver.
  ///   Defaults to false for callers whose rows don't draw the glyphs.
  public static func getAccessibilityLabel(
    for item: SimpleLibraryItem,
    useOriginalFileName: Bool = false,
    includeSource: Bool = false
  ) -> String {
    let displayPercent = item.isFinished ? 100.0 : item.percentCompleted
    let remainingTime = item.duration - item.currentTime
    var remainingTimeLabel = "book_time_remaining_title".localized
    if remainingTime > 0 && remainingTime.isFinite {
      let parsedDuration = VoiceOverService.secondsToMinutes(remainingTime)
      remainingTimeLabel += !parsedDuration.isEmpty ? " \(parsedDuration)" : " 0"
    }
    let displayTitle = item.displayTitle(useOriginalFileName: useOriginalFileName)
    let sourcePrefix = includeSource ? self.sourcePrefix(for: item) : ""
    switch item.type {
    case .book:
      return sourcePrefix + String.localizedStringWithFormat(
        "voiceover_book_progress".localized,
        displayTitle,
        item.details,
        displayPercent,
        item.durationFormatted
      ) + ", \(remainingTimeLabel)"
    case .folder:
      return sourcePrefix + String.localizedStringWithFormat(
        "voiceover_playlist_progress".localized,
        displayTitle,
        displayPercent
      )
    case .bound:
      return sourcePrefix + String.localizedStringWithFormat(
        "voiceover_bound_books_progress".localized,
        displayTitle,
        displayPercent,
        item.durationFormatted
      ) + ", \(remainingTimeLabel)"
    }
  }

  /// `"Jellyfin, "` — the spoken counterpart of the provider glyphs, and in the same
  /// position: they lead the subtitle line, so the names lead the announcement.
  ///
  /// Deliberately unlocalized. These are brand names, and wrapping them in a `"from %@"` key
  /// would be worse than bare: `localized` is a plain `NSLocalizedString` with no fallback to
  /// Base, so every locale missing the key would announce the key itself and swallow the name.
  /// Empty when the item isn't linked to a media server.
  private static func sourcePrefix(for item: SimpleLibraryItem) -> String {
    let providers = (item.externalResources?.displayOrderedMediaServerResources ?? [])
      .map { $0.providerName.capitalized }

    guard !providers.isEmpty else { return "" }

    return providers.joined(separator: ", ") + ", "
  }

  // MARK: - PlayerMetaView

  public static func playerMetaText(
    title: String,
    author: String
  ) -> String {
    return String(describing: String.localizedStringWithFormat("voiceover_book_info".localized, title, author))
  }

  // MARK: - ArtworkControl

  public static func rewindText() -> String {
    if PlayerManager.isRewindChapterSkip {
      return "chapters_previous_title".localized
    }
    return String(
      describing: String.localizedStringWithFormat(
        "voiceover_rewind_time".localized,
        self.secondsToMinutes(PlayerManager.rewindInterval.rounded())
      )
    )
  }

  public static func fastForwardText() -> String {
    if PlayerManager.isForwardChapterSkip {
      return "chapters_next_title".localized
    }
    return String(
      describing: String.localizedStringWithFormat(
        "voiceover_forward_time".localized,
        self.secondsToMinutes(PlayerManager.forwardInterval.rounded())
      )
    )
  }

  public static func secondsToMinutes(_ interval: TimeInterval) -> String {
    let absInterval = abs(interval)
    let hours = (absInterval / 3600.0).rounded(.towardZero)
    let minutes = (absInterval.truncatingRemainder(dividingBy: 3600) / 60).rounded(.towardZero)
    let seconds = absInterval.truncatingRemainder(dividingBy: 60).truncatingRemainder(dividingBy: 60).rounded()

    let hoursText = self.pluralization(amount: Int(hours), interval: .hour)
    let minutesText = self.pluralization(amount: Int(minutes), interval: .minute)
    let secondsText = self.pluralization(amount: Int(seconds), interval: .second)

    return String("\(hoursText)\(minutesText)\(secondsText)".dropLast())
  }

  private static func pluralization(amount: Int, interval: TimeUnit) -> String {
    switch amount {
    case 1:
      return "\(amount) \(interval.rawValue) "
    case amount where amount > 1:
      return "\(amount) \(interval.rawValue)s "
    default:
      return ""
    }
  }
}

private enum TimeUnit: String {
  case minute
  case second
  case hour
}
