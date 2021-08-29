//
//  PlayerViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/8/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import AVFoundation
import AVKit
import BookPlayerKit
import Combine
import MediaPlayer
import StoreKit
import Themeable
import UIKit

class PlayerViewController: UIViewController, TelemetryProtocol {
  @IBOutlet private weak var closeButton: UIButton!
  @IBOutlet private weak var closeButtonTop: NSLayoutConstraint!
  @IBOutlet private weak var bottomToolbar: UIToolbar!
  @IBOutlet private weak var speedButton: UIBarButtonItem!
  @IBOutlet private weak var sleepButton: UIBarButtonItem!
  @IBOutlet private var sleepLabel: UIBarButtonItem!
  @IBOutlet private var chaptersButton: UIBarButtonItem!
  @IBOutlet private weak var moreButton: UIBarButtonItem!
  @IBOutlet private weak var backgroundImage: UIImageView!

  @IBOutlet private weak var artworkControl: ArtworkControl!
  @IBOutlet private weak var progressSlider: ProgressSlider!
  @IBOutlet private weak var currentTimeLabel: UILabel!
  @IBOutlet private weak var maxTimeButton: UIButton!
  @IBOutlet private weak var progressButton: UIButton!
  @IBOutlet weak var previousChapterButton: UIButton!
  @IBOutlet weak var nextChapterButton: UIButton!
  @IBOutlet weak var rewindIconView: PlayerJumpIconRewind!
  @IBOutlet weak var playIconView: PlayPauseIconView!
  @IBOutlet weak var forwardIconView: PlayerJumpIconForward!
  @IBOutlet weak var containerItemStackView: UIStackView!

  private var themedStatusBarStyle: UIStatusBarStyle?
  private var blurEffectView: UIVisualEffectView?
  private var panGestureRecognizer: UIPanGestureRecognizer!
  private let darknessThreshold: CGFloat = 0.2
  private let dismissThreshold: CGFloat = 44.0 * UIScreen.main.nativeScale
  private var dismissFeedbackTriggered = false
  private var chapterBeforeSliderValueChange: Chapter?
  private var prefersChapterContext = UserDefaults.standard.bool(forKey: Constants.UserDefaults.chapterContextEnabled.rawValue)
  private var prefersRemainingTime = UserDefaults.standard.bool(forKey: Constants.UserDefaults.remainingTimeEnabled.rawValue)

  private var disposeBag = Set<AnyCancellable>()
  private var viewModel: PlayerViewModel!
  var currentBook: Book!

  // computed properties
  override var preferredStatusBarStyle: UIStatusBarStyle {
    let style = ThemeManager.shared.useDarkVariant ? UIStatusBarStyle.lightContent : UIStatusBarStyle.default
    return self.themedStatusBarStyle ?? style
  }

  // MARK: - Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()

    setup()

    setUpTheming()

    setupPlayerView(with: self.currentBook)

    setupToolbar()

    setupGestures()

    bindGeneralObservers()

    bindPlaybackControlsObservers()

    bindTimerObservers()

    self.containerItemStackView.setCustomSpacing(26, after: self.artworkControl)
  }

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let navigationController = segue.destination as? UINavigationController,
       let viewController = navigationController.viewControllers.first as? ChaptersViewController,
       let currentChapter = self.currentBook.currentChapter {
      viewController.chapters = self.currentBook.chapters?.array as? [Chapter] ?? []
      viewController.currentChapter = currentChapter
      viewController.didSelectChapter = { selectedChapter in
        // Don't set the chapter, set the new time which will set the chapter in didSet
        // Add a fraction of a second to make sure we start after the end of the previous chapter
        PlayerManager.shared.jumpTo(selectedChapter.start + 0.01)
        self.sendSignal(.chapterAction, with: nil)
      }
    }
  }

  // Prevents dragging the view down from changing the safeAreaInsets.top
  // Note: I'm pretty sure there is a better solution for this that I haven't found yet - @pichfl
  override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()

    let window = UIApplication.shared.windows[0]
    let insets: UIEdgeInsets = window.safeAreaInsets

    self.closeButtonTop.constant = self.view.safeAreaInsets.top == 0.0 ? insets.top : 0
  }

  func setup() {
    NotificationCenter.default.post(name: .playerPresented, object: nil)
    self.closeButton.accessibilityLabel = "voiceover_dismiss_player_title".localized
    self.viewModel = PlayerViewModel()
  }

  func setupPlayerView(with currentBook: Book) {
    self.artworkControl.book = currentBook

    self.speedButton.title = self.formatSpeed(PlayerManager.shared.speed)
    self.speedButton.accessibilityLabel = String(describing: self.formatSpeed(PlayerManager.shared.speed) + " \("speed_title".localized)")

    self.updateToolbar()

    guard !currentBook.isFault else { return }

    let currentArtwork = currentBook.getArtwork(for: themeProvider.currentTheme)

    if currentBook.usesDefaultArtwork {
      self.backgroundImage.isHidden = true
    } else {
      self.backgroundImage.isHidden = false
      self.backgroundImage.image = currentArtwork
    }

    self.setProgress()

    applyTheme(self.themeProvider.currentTheme)
    self.progressSlider.setNeedsDisplay()

    // Solution thanks to https://forums.developer.apple.com/thread/63166#180445
    self.modalPresentationCapturesStatusBarAppearance = true

    self.setNeedsStatusBarAppearanceUpdate()
  }

  private func setProgress() {
    guard let book = self.currentBook, !book.isFault else {
      self.progressButton.setTitle("", for: .normal)

      return
    }

    if !self.progressSlider.isTracking {
      self.currentTimeLabel.text = self.formatTime(book.currentTimeInContext(self.prefersChapterContext))
      self.currentTimeLabel.accessibilityLabel = String(describing: String.localizedStringWithFormat("voiceover_chapter_time_title".localized, VoiceOverService.secondsToMinutes(book.currentTimeInContext(self.prefersChapterContext))))

      let maxTimeInContext = book.maxTimeInContext(self.prefersChapterContext, self.prefersRemainingTime)
      self.maxTimeButton.setTitle(self.formatTime(maxTimeInContext), for: .normal)
      let prefix = self.prefersRemainingTime
        ? "chapter_time_remaining_title".localized
        : "chapter_duration_title".localized
      self.maxTimeButton.accessibilityLabel = String(describing: prefix + VoiceOverService.secondsToMinutes(maxTimeInContext))
    }

    guard
      self.prefersChapterContext,
      book.hasChapters,
      let chapters = book.chapters,
      let currentChapter = book.currentChapter else {
      if !self.progressSlider.isTracking {
        self.progressButton.setTitle("\(Int(round(book.progressPercentage * 100)))%", for: .normal)

        self.progressSlider.value = Float(book.progressPercentage)
        self.progressSlider.setNeedsDisplay()
        let prefix = self.prefersRemainingTime
          ? "book_time_remaining_title".localized
          : "book_duration_title".localized
        let maxTimeInContext = book.maxTimeInContext(self.prefersChapterContext, self.prefersRemainingTime)
        self.maxTimeButton.accessibilityLabel = String(describing: prefix + VoiceOverService.secondsToMinutes(maxTimeInContext))
      }

      return
    }

    self.progressButton.isHidden = false
    self.progressButton.setTitle(String.localizedStringWithFormat("player_chapter_description".localized, currentChapter.index, chapters.count), for: .normal)

    if !self.progressSlider.isTracking {
      self.progressSlider.value = Float((book.currentTime - currentChapter.start) / currentChapter.duration)
      self.progressSlider.setNeedsDisplay()
    }
  }
}

// MARK: - Observers
extension PlayerViewController {
  func bindPlaybackControlsObservers() {
    // Playback controls
    self.playIconView.observeActionEvents()
      .sink { [weak self] _ in
        self?.viewModel.handlePlayPauseAction()
      }
      .store(in: &disposeBag)

    self.rewindIconView.observeActionEvents()
      .sink { [weak self] _ in
        self?.viewModel.handleRewindAction()
      }
      .store(in: &disposeBag)

    self.forwardIconView.observeActionEvents()
      .sink { [weak self] _ in
        self?.viewModel.handleForwardAction()
      }
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .bookPlaying)
      .sink { [weak self] _ in
        self?.setProgress()
      }
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .bookPaused)
      .sink { [weak self] _ in
        self?.playIconView.isPlaying = false
      }
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .bookPlayed)
      .sink { [weak self] _ in
        self?.playIconView.isPlaying = true
      }
      .store(in: &disposeBag)
  }

  func bindTimerObservers() {
    NotificationCenter.default.publisher(for: .timerStart)
      .sink { [weak self] _ in
        self?.updateToolbar(true, animated: true)
      }
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .timerProgress)
      .sink { [weak self] notification in
        guard
          let self = self,
          let userInfo = notification.userInfo,
          let timeLeft = userInfo["timeLeft"] as? Double
        else {
          return
        }

        self.sleepLabel.title = SleepTimer.shared.durationFormatter.string(from: timeLeft)
        if let timeLeft = SleepTimer.shared.durationFormatter.string(from: timeLeft) {
          let remainingTitle = String(describing: String.localizedStringWithFormat("sleep_remaining_title".localized, timeLeft))
          self.sleepLabel.accessibilityLabel = String(describing: remainingTitle)
        }
      }
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .timerEnd)
      .sink { [weak self] _ in
        self?.sleepLabel.title = ""
        self?.updateToolbar(false, animated: true)
      }
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .timerSelected)
      .sink { [weak self] notification in
        guard
          let userInfo = notification.userInfo,
          let timeLeft = userInfo["timeLeft"] as? Double
        else {
          return
        }

        if timeLeft == -2 {
          self?.updateToolbar(true, animated: true)
          self?.sleepLabel.title = "active_title".localized
        }
      }
      .store(in: &disposeBag)
  }

  func bindGeneralObservers() {
    // Review the app
    NotificationCenter.default.publisher(for: .requestReview)
      .sink { [weak self] _ in
        self?.viewModel.requestReview()
      }
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .bookEnd)
      .sink { [weak self] _ in
        self?.playIconView.isPlaying = false
        self?.viewModel.requestReview()
      }
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .bookChange)
      .sink { [weak self] notification in
        guard
          let userInfo = notification.userInfo,
          let book = userInfo["book"] as? Book
        else {
          return
        }
        self?.currentBook = book
        self?.setupPlayerView(with: book)
      }
      .store(in: &disposeBag)
  }
}

// MARK: - Toolbar
extension PlayerViewController {
  func setupToolbar() {
    self.bottomToolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
    self.bottomToolbar.setShadowImage(UIImage(), forToolbarPosition: .any)
    self.sleepLabel.title = SleepTimer.shared.isEndChapterActive() ? "active_title".localized : ""
    self.speedButton.setTitleTextAttributes([NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18.0, weight: .semibold)], for: .normal)

    if SleepTimer.shared.isActive() {
        self.updateToolbar(true, animated: true)
    }
  }

  func updateToolbar(_ showTimerLabel: Bool = false, animated: Bool = false) {
    let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

    var items: [UIBarButtonItem] = [
      self.speedButton,
      spacer,
      self.sleepButton
    ]

    if showTimerLabel {
      items.append(self.sleepLabel)
    }

    let chapterCount = self.currentBook.chapters?.count ?? 0
    self.chaptersButton.isEnabled = self.currentBook.hasChapters && chapterCount > 1

    items.append(spacer)
    items.append(self.chaptersButton)

    let avRoutePickerBarButtonItem = UIBarButtonItem(customView: AVRoutePickerView(frame: CGRect(x: 0.0, y: 0.0, width: 20.0, height: 20.0)))

    avRoutePickerBarButtonItem.isAccessibilityElement = true
    avRoutePickerBarButtonItem.accessibilityLabel = "audio_source_title".localized
    items.append(spacer)
    items.append(avRoutePickerBarButtonItem)

    items.append(spacer)
    items.append(self.moreButton)

    self.bottomToolbar.setItems(items, animated: animated)
  }
}

// MARK: - Actions

extension PlayerViewController {
  // MARK: - Interface actions

  @IBAction func dismissPlayer() {
    self.dismiss(animated: true, completion: nil)

    NotificationCenter.default.post(name: .playerDismissed, object: nil, userInfo: nil)
  }

  // MARK: - Toolbar actions

  @IBAction func setSpeed() {
    let actionSheet = UIAlertController(title: nil, message: "player_speed_title".localized, preferredStyle: .actionSheet)

    for speed in PlayerManager.speedOptions {
      if speed == PlayerManager.shared.speed {
        actionSheet.addAction(UIAlertAction(title: "\u{00A0} \(speed) ✓", style: .default, handler: nil))
      } else {
        actionSheet.addAction(UIAlertAction(title: "\(speed)", style: .default, handler: { _ in
          PlayerManager.shared.speed = speed

          self.speedButton.title = self.formatSpeed(speed)
        }))
      }
    }

    actionSheet.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))

    self.present(actionSheet, animated: true, completion: nil)
  }

  @IBAction func setSleepTimer() {
    let actionSheet = SleepTimer.shared.actionSheet()
    self.present(actionSheet, animated: true, completion: nil)
  }

  @IBAction func showMore() {
    guard PlayerManager.shared.hasLoadedBook else {
      return
    }

    let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

    actionSheet.addAction(UIAlertAction(title: "jump_start_title".localized, style: .default, handler: { _ in
      PlayerManager.shared.pause()
      PlayerManager.shared.jumpTo(0.0)
    }))

    let markTitle = self.currentBook.isFinished ? "mark_unfinished_title".localized : "mark_finished_title".localized

    actionSheet.addAction(UIAlertAction(title: markTitle, style: .default, handler: { _ in
      PlayerManager.shared.pause()
      PlayerManager.shared.markAsCompleted(!self.currentBook.isFinished)
    }))

    actionSheet.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))

    self.present(actionSheet, animated: true, completion: nil)
  }

  // MARK: - Slider actions
  @IBAction func toggleMaxTime(_ sender: UIButton) {
    self.prefersRemainingTime = !self.prefersRemainingTime
    UserDefaults.standard.set(self.prefersRemainingTime, forKey: Constants.UserDefaults.remainingTimeEnabled.rawValue)
    self.setProgress()
  }

  @IBAction func toggleProgressState(_ sender: UIButton) {
    self.prefersChapterContext = !self.prefersChapterContext
    UserDefaults.standard.set(self.prefersChapterContext, forKey: Constants.UserDefaults.chapterContextEnabled.rawValue)
    self.setProgress()
  }

  @IBAction func sliderDown(_ sender: UISlider) {
    self.artworkControl.isUserInteractionEnabled = false
    self.artworkControl.setAnchorPoint(anchorPoint: CGPoint(x: 0.5, y: 0.3))

    self.chapterBeforeSliderValueChange = self.currentBook?.currentChapter
  }

  @IBAction func sliderUp(_ sender: UISlider) {
    self.artworkControl.isUserInteractionEnabled = true

    // Adjust the animation duration based on the distance of the thumb to the slider's center
    // This way the corners which look further away take a little longer to rest
    let duration = TimeInterval(abs(sender.value * 2 - 1) * 0.15 + 0.15)

    UIView.animate(withDuration: duration, delay: 0.0, options: [.curveEaseIn, .beginFromCurrentState], animations: {
      self.artworkControl.layer.transform = CATransform3DIdentity
    }, completion: { _ in
      self.artworkControl.layer.zPosition = 0
      self.artworkControl.setAnchorPoint(anchorPoint: CGPoint(x: 0.5, y: 0.5))
    })

    guard let book = self.currentBook,
          !book.isFault else { return }

    // Setting progress here instead of in `sliderValueChanged` to only register the value when the interaction
    // has ended, while still previwing the expected new time and progress in labels and display
    var newTime = TimeInterval(sender.value) * book.duration

    if self.prefersChapterContext, let currentChapter = book.currentChapter {
      newTime = currentChapter.start + TimeInterval(sender.value) * currentChapter.duration
    }

    PlayerManager.shared.jumpTo(newTime)
  }

  @IBAction func sliderValueChanged(_ sender: UISlider) {
    // This should be in ProgressSlider, but how to achieve that escapes my knowledge
    self.progressSlider.setNeedsDisplay()

    guard let book = self.currentBook,
          !book.isFault else { return }

    var newTimeToDisplay = TimeInterval(sender.value) * book.duration

    if self.prefersChapterContext, let currentChapter = self.chapterBeforeSliderValueChange {
      newTimeToDisplay = TimeInterval(sender.value) * currentChapter.duration
    }

    self.currentTimeLabel.text = self.formatTime(newTimeToDisplay)

    if !book.hasChapters || !self.prefersChapterContext {
      self.progressButton.setTitle("\(Int(round(sender.value * 100)))%", for: .normal)
    }

    if self.prefersRemainingTime {
      let durationTimeInContext = book.durationTimeInContext(self.prefersChapterContext)
      self.maxTimeButton.setTitle(self.formatTime(newTimeToDisplay - durationTimeInContext), for: .normal)
    }
  }
}

extension PlayerViewController: UIGestureRecognizerDelegate {
  func setupGestures() {
    self.panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panAction))
    self.panGestureRecognizer.delegate = self
    self.panGestureRecognizer.maximumNumberOfTouches = 1
    self.panGestureRecognizer.cancelsTouchesInView = true

    self.view.addGestureRecognizer(self.panGestureRecognizer)
  }

  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    if gestureRecognizer == self.panGestureRecognizer {
      return limitPanAngle(self.panGestureRecognizer, degreesOfFreedom: 45.0, comparator: .greaterThan)
    }

    return true
  }

  private func updatePresentedViewForTranslation(_ yTranslation: CGFloat) {
    let translation: CGFloat = rubberBandDistance(yTranslation, dimension: self.view.frame.height, constant: 0.55)

    self.view?.transform = CGAffineTransform(translationX: 0, y: max(translation, 0.0))
  }

  @objc private func panAction(gestureRecognizer: UIPanGestureRecognizer) {
    guard gestureRecognizer.isEqual(self.panGestureRecognizer) else {
      return
    }

    switch gestureRecognizer.state {
    case .began:
      gestureRecognizer.setTranslation(CGPoint(x: 0, y: 0), in: self.view.superview)

    case .changed:
      let translation = gestureRecognizer.translation(in: self.view)

      self.updatePresentedViewForTranslation(translation.y)

      if translation.y > self.dismissThreshold, !self.dismissFeedbackTriggered {
        self.dismissFeedbackTriggered = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
      }

    case .ended, .cancelled, .failed:
      let translation = gestureRecognizer.translation(in: self.view)

      if translation.y > self.dismissThreshold {
        self.dismissPlayer()
        return
      }

      self.dismissFeedbackTriggered = false

      UIView.animate(withDuration: 0.3,
                     delay: 0.0,
                     usingSpringWithDamping: 0.75,
                     initialSpringVelocity: 1.5,
                     options: .preferredFramesPerSecond60,
                     animations: {
                      self.view?.transform = .identity
                     })

    default: break
    }
  }
}

extension PlayerViewController: Themeable {
    func applyTheme(_ theme: Theme) {
        self.themedStatusBarStyle = theme.useDarkVariant
            ? .lightContent
            : .default
        setNeedsStatusBarAppearanceUpdate()

        self.view.backgroundColor = theme.systemBackgroundColor
        self.bottomToolbar.tintColor = theme.primaryColor
        self.closeButton.tintColor = theme.linkColor

        // Apply the blurred view in relation to the brightness and luminance of the background color.
        // This makes darker backgrounds stay interesting
        self.backgroundImage.alpha = 0.1 + min((1 - theme.systemBackgroundColor.luminance) * (1 - theme.systemBackgroundColor.brightness), 0.7)

        self.blurEffectView?.removeFromSuperview()

        let blur = UIBlurEffect(style: theme.useDarkVariant ? UIBlurEffect.Style.dark : UIBlurEffect.Style.light)
        let blurView = UIVisualEffectView(effect: blur)

        blurView.frame = self.view.bounds

        self.blurEffectView = blurView
        self.backgroundImage.addSubview(blurView)

      // controls
      self.progressSlider.minimumTrackTintColor = theme.primaryColor
      self.progressSlider.maximumTrackTintColor = theme.primaryColor.withAlpha(newAlpha: 0.3)

//      self.artworkControl.iconColor = .white

      self.currentTimeLabel.textColor = theme.primaryColor
      self.maxTimeButton.setTitleColor(theme.primaryColor, for: .normal)
      self.progressButton.setTitleColor(theme.primaryColor, for: .normal)
    }
}
