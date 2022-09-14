import BookPlayerKit
import Foundation

class VoiceOverService {
    var title: String?
    var subtitle: String?
    var type: SimpleItemType!
    var progress: Double?

    // MARK: - BookCellView

    public func bookCellView(type: SimpleItemType, title: String?, subtitle: String?, progress: Double?) -> String {
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.progress = progress

        switch type {
        case .book:
          return self.bookText()
        case .folder:
          return self.regularFolderText()
        case .bound:
          return self.boundFolderText()
        }
    }

    fileprivate func bookText() -> String {
        let voiceOverTitle = self.title ?? Loc.VoiceoverNoTitle.string
        let voiceOverSubtitle = self.subtitle ?? Loc.VoiceoverNoAuthor.string
      return Loc.VoiceoverBookProgress(voiceOverTitle, voiceOverSubtitle, self.progressPercent()).string
    }

    fileprivate func fileText() -> String {
        let voiceOverTitle = self.title ?? Loc.VoiceoverNoFileTitle.string
        let voiceOverSubtitle = self.subtitle ?? Loc.VoiceoverNoFileSubtitle.string
        return "\(voiceOverTitle) \(voiceOverSubtitle)"
    }

  fileprivate func regularFolderText() -> String {
      let voiceOverTitle = self.title ?? Loc.VoiceoverNoPlaylistTitle.string
      return Loc.VoiceoverPlaylistProgress(voiceOverTitle, self.progressPercent()).string
  }

  fileprivate func boundFolderText() -> String {
      let voiceOverTitle = self.title ?? Loc.VoiceoverNoBoundBooksTitle.string
      return Loc.VoiceoverBoundBooksProgress(voiceOverTitle, self.progressPercent()).string
  }

    fileprivate func progressPercent() -> Int {
        guard let progress = progress, !progress.isNaN else {
            return 0
        }
        return Int(progress * 100)
    }

    // MARK: PlayerMetaView

    public func playerMetaText(item: PlayableItem) -> String {
      let title: String = item.title
      let author: String = item.author

      return String(describing: Loc.VoiceoverBookInfo(title, author).string)
    }

    // MARK: - ArtworkControl

    public static func rewindText() -> String {
        return Loc.VoiceoverRewindTime(self.secondsToMinutes(PlayerManager.rewindInterval.rounded())).string
    }

    public static func fastForwardText() -> String {
        return String(describing: Loc.VoiceoverForwardTime(self.secondsToMinutes(PlayerManager.forwardInterval.rounded())).string)
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
