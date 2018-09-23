import Foundation

class VoiceOverService {
    var title: String?
    var subtitle: String?
    var type: BookCellType!
    var progress: Double?

    // MARK: - BookCellView

    public func bookCellView(type: BookCellType, title: String?, subtitle: String?, progress: Double?) -> String {
        self.type     = type
        self.title    = title
        self.subtitle = subtitle
        self.progress = progress

        switch type {
        case .book:
            return bookText()
        case .file:
            return fileText()
        case .playlist:
            return playlistText()
        }
    }

    fileprivate func bookText() -> String {
        let voiceOverTitle          = title ?? "No Title"
        let voiceOverSubtitle       = subtitle ?? "No Author"
        return "\(voiceOverTitle) by \(voiceOverSubtitle) \(progressPercent())% Completed"
    }

    fileprivate func fileText() -> String {
        let voiceOverTitle          = title ?? "No File Title"
        let voiceOverSubtitle       = subtitle ?? "No File Subtitle"
        return "\(voiceOverTitle) \(voiceOverSubtitle)"
    }

    fileprivate func playlistText() -> String {
        let voiceOverTitle          = title ?? "No Playlist Title"
        return "\(voiceOverTitle) Playlist \(progressPercent())% Completed"
    }

    fileprivate func progressPercent() -> Int {
        guard let progress = progress else {
            return 0
        }
        return Int(progress * 100)
    }

    // MARK: PlayerMetaView

    public func playerMetaText(book: Book) -> String {
        guard let currentChapter = book.currentChapter else {
            return String(describing: book.title + " by " + book.author)
        }
        return String(describing: book.title + " by " + book.author + ", chapter " + String(describing: currentChapter.index))
    }

    // MARK: - ArtworkControl
    public static func rewindText() -> String {
        return "Rewind " + self.secondsToMinutes(PlayerManager.shared.rewindInterval.rounded())
    }

    public static func fastForwardText() -> String {
        return "Fast Forward " + self.secondsToMinutes(PlayerManager.shared.forwardInterval.rounded())
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
