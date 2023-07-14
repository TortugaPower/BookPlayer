import BookPlayerKit
import Foundation

class VoiceOverService {
  // MARK: PlayerMetaView

  public static func playerMetaText(
    title: String,
    author: String
  ) -> String {
    return String(describing: String.localizedStringWithFormat("voiceover_book_info".localized, title, author))
  }

  // MARK: - ArtworkControl

  public static func rewindText() -> String {
    return String(describing: String.localizedStringWithFormat("voiceover_rewind_time".localized, self.secondsToMinutes(PlayerManager.rewindInterval.rounded())))
  }

  public static func fastForwardText() -> String {
    return String(describing: String.localizedStringWithFormat("voiceover_forward_time".localized, self.secondsToMinutes(PlayerManager.forwardInterval.rounded())))
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
