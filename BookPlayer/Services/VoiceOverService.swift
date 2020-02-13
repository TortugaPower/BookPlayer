import BookPlayerKit
import Foundation

class VoiceOverService {
    var title: String?
    var subtitle: String?
    var type: BookCellType!
    var progress: Double?

    // MARK: - BookCellView

    public func bookCellView(type: BookCellType, title: String?, subtitle: String?, progress: Double?) -> String {
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.progress = progress

        switch type {
        case .book:
            return self.bookText()
        case .file:
            return self.fileText()
        case .playlist:
            return self.playlistText()
        }
    }

    fileprivate func bookText() -> String {
        let voiceOverTitle = title ?? "voiceover_no_title".localized
        let voiceOverSubtitle = subtitle ?? "voiceover_no_author".localized
        return String.localizedStringWithFormat("voiceover_book_progress".localized, voiceOverTitle, voiceOverSubtitle, self.progressPercent())
    }

    fileprivate func fileText() -> String {
        let voiceOverTitle = title ?? "voiceover_no_file_title".localized
        let voiceOverSubtitle = subtitle ?? "voiceover_no_file_subtitle".localized
        return "\(voiceOverTitle) \(voiceOverSubtitle)"
    }

    fileprivate func playlistText() -> String {
        let voiceOverTitle = title ?? "voiceover_no_playlist_title".localized
        return String.localizedStringWithFormat("voiceover_playlist_progress".localized, voiceOverTitle, self.progressPercent())
    }

    fileprivate func progressPercent() -> Int {
        guard let progress = progress, !progress.isNaN else {
            return 0
        }
        return Int(progress * 100)
    }

    // MARK: PlayerMetaView

    public func playerMetaText(book: Book) -> String {
        let title: String = book.title != nil
            ? book.title
            : "voiceover_unknown_title".localized
        let author: String = book.author != nil
            ? book.author
            : "voiceover_unknown_author".localized

        guard let currentChapter = book.currentChapter else {
            return String(describing: String.localizedStringWithFormat("voiceover_book_info".localized, title, author))
        }

        return String(describing: String.localizedStringWithFormat("voiceover_book_chapter".localized, title, author, String(describing: currentChapter.index)))
    }

    // MARK: - ArtworkControl

    public static func rewindText() -> String {
        return String(describing: String.localizedStringWithFormat("voiceover_rewind_time".localized, self.secondsToMinutes(PlayerManager.shared.rewindInterval.rounded())))
    }

    public static func fastForwardText() -> String {
        return String(describing: String.localizedStringWithFormat("voiceover_forward_time".localized, self.secondsToMinutes(PlayerManager.shared.forwardInterval.rounded())))
    }

    public static func secondsToMinutes(_ interval: TimeInterval) -> String {
        let absInterval = abs(interval)
        let hours = (absInterval / 3600.0).rounded(.towardZero)
        let minutes = ((absInterval.truncatingRemainder(dividingBy: 3600)) / 60).rounded(.towardZero)
        let seconds = ((absInterval.truncatingRemainder(dividingBy: 60)).truncatingRemainder(dividingBy: 60)).rounded()

        let hoursText = pluralization(amount: Int(hours), interval: .hour)
        let minutesText = pluralization(amount: Int(minutes), interval: .minute)
        let secondsText = pluralization(amount: Int(seconds), interval: .second)

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
