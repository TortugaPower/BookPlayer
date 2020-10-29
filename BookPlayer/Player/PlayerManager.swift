//
//  PlayerManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/31/17.
//  Copyright © 2017 Tortuga Power. All rights reserved.
//

import AVFoundation
import BookPlayerKit
import Foundation
import MediaPlayer

// swiftlint:disable file_length

class PlayerManager: NSObject {
    static let shared = PlayerManager()

    static let speedOptions: [Float] = [3, 2.5, 2, 1.75, 1.5, 1.25, 1.15, 1.1, 1, 0.9, 0.75, 0.5]

    private var audioPlayer = AVPlayer()

    private var playerItem: AVPlayerItem?

    private var observeStatus: Bool = false {
        didSet {
            guard oldValue != self.observeStatus else { return }

            if self.observeStatus {
                self.playerItem?.addObserver(self, forKeyPath: "status", options: .new, context: nil)
            } else {
                self.playerItem?.removeObserver(self, forKeyPath: "status")
            }
        }
    }

    var currentBook: Book? {
        didSet {
            guard let book = currentBook,
                let fileURL = book.fileURL else { return }

            let bookAsset = AVURLAsset(url: fileURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
            self.playerItem = AVPlayerItem(asset: bookAsset)
            self.playerItem?.audioTimePitchAlgorithm = .timeDomain
        }
    }

    private var nowPlayingInfo = [String: Any]()

    private let queue = OperationQueue()

    private(set) var hasLoadedBook = false

    private var rateObserver: NSKeyValueObservation?

    private override init() {
        super.init()
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

        self.rateObserver = self.audioPlayer.observe(\.rate, options: [.new]) { _, change in
            guard let newValue = change.newValue, newValue == 0 else { return }

            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .bookPaused, object: nil)
                WatchConnectivityService.sharedManager.sendMessage(message: ["notification": "bookPaused" as AnyObject])
            }
        }
        self.audioPlayer.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) { [weak self] _ in
            guard let self = self else {
                return
            }

            self.update()
        }

        // Only route audio for AirPlay
        self.audioPlayer.allowsExternalPlayback = false

        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying(_:)), name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }

    func load(_ book: Book, completion: @escaping (Bool) -> Void) {
        if self.currentBook != nil {
            self.stop()
        }

        self.currentBook = book

        self.queue.addOperation {
            // try loading the player
            guard let item = self.playerItem,
                book.duration > 0 else {
                DispatchQueue.main.async {
                    self.currentBook = nil

                    completion(false)
                }

                return
            }

            self.audioPlayer.replaceCurrentItem(with: nil)
            self.audioPlayer.replaceCurrentItem(with: item)

            self.boostVolume = UserDefaults.standard.bool(forKey: Constants.UserDefaults.boostVolumeEnabled.rawValue)

            // Update UI on main thread
            DispatchQueue.main.async {
                // Set book metadata for lockscreen and control center
                self.nowPlayingInfo = [
                    MPNowPlayingInfoPropertyDefaultPlaybackRate: self.speed
                ]

                self.setNowPlayingBookTitle()
                self.setNowPlayingBookTime()

                self.nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: book.artwork.size,
                                                                                     requestHandler: { (_) -> UIImage in
                                                                                         book.artwork
                })

                MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo

                if book.currentTime > 0.0 {
                    // if book is truly finished, start book again to avoid autoplaying next one
                    let time = book.currentTime == book.duration ? 0 : book.currentTime
                    self.jumpTo(time)
                }

                NotificationCenter.default.post(name: .bookReady, object: nil, userInfo: ["book": book])

                self.hasLoadedBook = true
                completion(true)
            }
        }
    }

    // Called every second by the timer
    @objc func update() {
        guard let book = self.currentBook,
            let fileURL = book.fileURL,
            let playerItem = self.playerItem,
            playerItem.status == .readyToPlay else {
            return
        }

        let currentTime = CMTimeGetSeconds(self.audioPlayer.currentTime())
        book.currentTime = currentTime

        let isPercentageDifferent = book.percentage != book.percentCompleted || (book.percentCompleted == 0 && book.progress > 0)

        book.percentCompleted = book.percentage

        DataManager.saveContext()
        UserActivityManager.shared.recordTime()

        // Notify
        if isPercentageDifferent {
            NotificationCenter.default.post(name: .updatePercentage,
                                            object: nil,
                                            userInfo: [
                                                "progress": book.progress,
                                                "fileURL": fileURL
                                            ] as [String: Any])
        }

        self.setNowPlayingBookTime()

        MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo

        // stop timer if the book is finished
        if Int(currentTime) == Int(book.duration) {
            // Once book a book is finished, ask for a review
            UserDefaults.standard.set(true, forKey: "ask_review")
            self.markAsCompleted(true)
        }

        if let currentChapter = book.currentChapter,
            book.currentTime > currentChapter.end || book.currentTime < currentChapter.start {
            book.updateCurrentChapter()
            self.setNowPlayingBookTitle()
            NotificationCenter.default.post(name: .chapterChange, object: nil, userInfo: nil)
        }

        let userInfo = [
            "time": currentTime,
            "fileURL": fileURL
        ] as [String: Any]

        // Notify
        NotificationCenter.default.post(name: .bookPlaying, object: nil, userInfo: userInfo)
    }

    // MARK: - Player states

    var isPlaying: Bool {
        return self.audioPlayer.timeControlStatus == .playing
    }

    var boostVolume: Bool = false {
        didSet {
            self.audioPlayer.volume = self.boostVolume
                ? Constants.Volume.boosted.rawValue
                : Constants.Volume.normal.rawValue
        }
    }

    var currentTime: TimeInterval {
        get {
            return CMTimeGetSeconds(self.audioPlayer.currentTime())
        }

        set {
            self.audioPlayer.seek(to: CMTime(seconds: newValue, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
        }
    }

    var speed: Float {
        get {
            guard let currentBook = self.currentBook else {
                return 1.0
            }

            let useGlobalSpeed = UserDefaults.standard.bool(forKey: Constants.UserDefaults.globalSpeedEnabled.rawValue)
            let globalSpeed = UserDefaults.standard.float(forKey: "global_speed")
            let localSpeed = currentBook.playlist?.speed ?? currentBook.speed
            let speed = useGlobalSpeed ? globalSpeed : localSpeed

            return speed > 0 ? speed : 1.0
        }

        set {
            guard let currentBook = self.currentBook else {
                return
            }

            currentBook.playlist?.speed = newValue
            currentBook.speed = newValue
            DataManager.saveContext()

            // set global speed
            if UserDefaults.standard.bool(forKey: Constants.UserDefaults.globalSpeedEnabled.rawValue) {
                UserDefaults.standard.set(newValue, forKey: "global_speed")
            }

            guard self.isPlaying else { return }

            self.audioPlayer.rate = newValue
        }
    }

    var rewindInterval: TimeInterval {
        get {
            if UserDefaults.standard.object(forKey: Constants.UserDefaults.rewindInterval.rawValue) == nil {
                return 30.0
            }

            return UserDefaults.standard.double(forKey: Constants.UserDefaults.rewindInterval.rawValue)
        }

        set {
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.rewindInterval.rawValue)

            MPRemoteCommandCenter.shared().skipBackwardCommand.preferredIntervals = [newValue] as [NSNumber]
        }
    }

    var forwardInterval: TimeInterval {
        get {
            if UserDefaults.standard.object(forKey: Constants.UserDefaults.forwardInterval.rawValue) == nil {
                return 30.0
            }

            return UserDefaults.standard.double(forKey: Constants.UserDefaults.forwardInterval.rawValue)
        }

        set {
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.forwardInterval.rawValue)

            MPRemoteCommandCenter.shared().skipForwardCommand.preferredIntervals = [newValue] as [NSNumber]
        }
    }

    func setNowPlayingBookTitle() {
        guard let currentBook = self.currentBook else {
            return
        }

        if currentBook.hasChapters, let currentChapter = currentBook.currentChapter {
            self.nowPlayingInfo[MPMediaItemPropertyTitle] = currentChapter.title
            self.nowPlayingInfo[MPMediaItemPropertyArtist] = currentBook.title
            self.nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = currentBook.author
        } else {
            self.nowPlayingInfo[MPMediaItemPropertyTitle] = currentBook.title
            self.nowPlayingInfo[MPMediaItemPropertyArtist] = currentBook.author
            self.nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = nil
        }
    }

    func setNowPlayingBookTime() {
        guard let currentBook = self.currentBook else {
            return
        }

        let prefersChapterContext = UserDefaults.standard.bool(forKey: Constants.UserDefaults.chapterContextEnabled.rawValue)
        let currentTimeInContext = currentBook.currentTimeInContext(prefersChapterContext)
        let maxTimeInContext = currentBook.maxTimeInContext(prefersChapterContext, false)

        self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.speed
        self.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTimeInContext
        self.nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = maxTimeInContext
        self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackProgress] = currentTimeInContext / maxTimeInContext
    }
}

// MARK: - Seek Controls

extension PlayerManager {
    func jumpTo(_ time: Double, fromEnd: Bool = false) {
        guard let currentBook = self.currentBook else { return }
        let newTime = min(max(fromEnd ? currentBook.duration - time : time, 0), currentBook.duration)

        self.audioPlayer.seek(to: CMTime(seconds: newTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))

        if !self.isPlaying, let currentBook = self.currentBook {
            UserDefaults.standard.set(Date(), forKey: "\(Constants.UserDefaults.lastPauseTime)_\(currentBook.identifier!)")
        }

        self.update()
    }

    func jumpBy(_ direction: Double) {
        guard let book = self.currentBook else { return }

        let newTime = book.getInterval(from: direction) + CMTimeGetSeconds(self.audioPlayer.currentTime())
        self.audioPlayer.seek(to: CMTime(seconds: newTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))

        self.update()
    }

    func forward() {
        self.jumpBy(self.forwardInterval)
    }

    func rewind() {
        self.jumpBy(-self.rewindInterval)
    }
}

// MARK: - Playback

extension PlayerManager {
    func play(_ autoplayed: Bool = false) {
        guard let currentBook = self.currentBook else { return }

        guard let item = self.playerItem,
            item.status == .readyToPlay else {
            // queue playback
            self.observeStatus = true
            return
        }

        UserActivityManager.shared.resumePlaybackActivity()

        if let library = currentBook.library ?? currentBook.playlist?.library {
            library.lastPlayedBook = currentBook
            DataManager.saveContext()
        }

        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            fatalError("Failed to activate the audio session")
        }

        let completed = Int(currentBook.duration) == Int(CMTimeGetSeconds(self.audioPlayer.currentTime()))

        if autoplayed, completed {
            return
        }

        // If book is completed, reset to start
        if completed {
            self.audioPlayer.seek(to: CMTime(seconds: 0, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
        }

        // Handle smart rewind.
        let lastPauseTimeKey = "\(Constants.UserDefaults.lastPauseTime)_\(currentBook.identifier!)"
        let smartRewindEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaults.smartRewindEnabled.rawValue)

        if smartRewindEnabled, let lastPlayTime: Date = UserDefaults.standard.object(forKey: lastPauseTimeKey) as? Date {
            let timePassed = Date().timeIntervalSince(lastPlayTime)
            let timePassedLimited = min(max(timePassed, 0), Constants.SmartRewind.threshold.rawValue)

            let delta = timePassedLimited / Constants.SmartRewind.threshold.rawValue

            // Using a cubic curve to soften the rewind effect for lower values and strengthen it for higher
            let rewindTime = pow(delta, 3) * Constants.SmartRewind.maxTime.rawValue

            let newPlayerTime = max(CMTimeGetSeconds(self.audioPlayer.currentTime()) - rewindTime, 0)

            UserDefaults.standard.set(nil, forKey: lastPauseTimeKey)

            self.audioPlayer.seek(to: CMTime(seconds: newPlayerTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
        }

        // Set play state on player and control center
        self.audioPlayer.playImmediately(atRate: self.speed)

        // Set last Play date
        currentBook.updatePlayDate()

        self.setNowPlayingBookTitle()

        DispatchQueue.main.async {
            CarPlayManager.shared.setNowPlayingInfo(with: currentBook)
            NotificationCenter.default.post(name: .bookPlayed, object: nil)
            WatchConnectivityService.sharedManager.sendMessage(message: ["notification": "bookPlayed" as AnyObject])
        }

        self.update()
    }

    // swiftlint:disable block_based_kvo
    // Using this instead of new form, because the new one wouldn't work properly on AVPlayerItem
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let path = keyPath, path == "status",
            let item = object as? AVPlayerItem,
            item.status == .readyToPlay else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }

        self.observeStatus = false

        self.play()
    }

    func pause() {
        guard let currentBook = self.currentBook else {
            return
        }

        self.observeStatus = false

        UserActivityManager.shared.stopPlaybackActivity()

        if let library = currentBook.library ?? currentBook.playlist?.library {
            library.lastPlayedBook = currentBook
            DataManager.saveContext()
        }

        self.update()

        // Set pause state on player and control center
        self.audioPlayer.pause()

        self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
        self.setNowPlayingBookTime()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo

        UserDefaults.standard.set(Date(), forKey: "\(Constants.UserDefaults.lastPauseTime)_\(currentBook.identifier!)")

        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // Toggle play/pause of book
    func playPause(autoplayed _: Bool = false) {
        // Pause player if it's playing
        if self.audioPlayer.timeControlStatus == .playing {
            self.pause()
        } else {
            self.play()
        }
    }

    func stop() {
        self.observeStatus = false

        self.audioPlayer.pause()

        UserActivityManager.shared.stopPlaybackActivity()

        var userInfo: [AnyHashable: Any]?

        if let book = self.currentBook {
            userInfo = ["book": book]

            if let library = book.library ?? book.playlist?.library {
                library.lastPlayedBook = nil
                DataManager.saveContext()
            }
        }

        self.currentBook = nil
        self.hasLoadedBook = false

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .bookStopped,
                                            object: nil,
                                            userInfo: userInfo)
        }
    }

    func markAsCompleted(_ flag: Bool) {
        guard let book = self.currentBook,
            let fileURL = book.fileURL else { return }

        book.markAsFinished(flag)
        DataManager.saveContext()

        NotificationCenter.default.post(name: .bookEnd,
                                        object: nil,
                                        userInfo: [
                                            "fileURL": fileURL
                                        ])
    }

    @objc
    func playerDidFinishPlaying(_ notification: Notification) {
        if let book = self.currentBook,
            let library = book.library ?? book.playlist?.library {
            library.lastPlayedBook = nil
            DataManager.saveContext()
        }

        self.update()

        guard let nextBook = self.currentBook?.nextBook() else { return }

        self.load(nextBook, completion: { success in
            guard success else { return }

            let userInfo = ["book": nextBook]

            NotificationCenter.default.post(name: .bookChange,
                                            object: nil,
                                            userInfo: userInfo)
        })
    }
}
