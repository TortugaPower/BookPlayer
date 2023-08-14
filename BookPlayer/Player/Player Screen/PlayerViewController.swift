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

class PlayerViewController: BaseViewController<PlayerCoordinator, PlayerViewModel>, Storyboarded {
  @IBOutlet private weak var closeButton: UIButton!
  @IBOutlet private weak var closeButtonTop: NSLayoutConstraint!
  @IBOutlet private weak var bottomToolbar: UIToolbar!
  @IBOutlet weak var toolbarBottomConstraint: NSLayoutConstraint!
  @IBOutlet private weak var speedButton: UIBarButtonItem!
  @IBOutlet private weak var sleepButton: UIBarButtonItem!
  @IBOutlet private var sleepLabel: UIBarButtonItem!
  @IBOutlet private var listButton: UIBarButtonItem!
  @IBOutlet private var bookmarkButton: UIBarButtonItem!
  @IBOutlet private weak var moreButton: UIBarButtonItem!

  @IBOutlet private weak var artworkControl: ArtworkControl!
  @IBOutlet private weak var progressSlider: ProgressSlider!
  @IBOutlet private weak var currentTimeLabel: UILabel!
  @IBOutlet private weak var chapterTitleButton: UIButton!
  @IBOutlet private weak var maxTimeButton: UIButton!
  @IBOutlet private weak var progressButton: UIButton!
  @IBOutlet weak var previousChapterButton: UIButton!
  @IBOutlet weak var nextChapterButton: UIButton!
  @IBOutlet weak var rewindIconView: PlayerJumpIconRewind!
  @IBOutlet weak var playIconView: PlayPauseIconView!
  @IBOutlet weak var forwardIconView: PlayerJumpIconForward!
  @IBOutlet weak var containerItemStackView: UIStackView!
  @IBOutlet weak var containerPlayerControlsStackView: UIStackView!
  @IBOutlet weak var containerChapterControlsStackView: UIStackView!
  @IBOutlet weak var containerProgressControlsStackView: UIStackView!
  private var themedStatusBarStyle: UIStatusBarStyle?
  private var panGestureRecognizer: UIPanGestureRecognizer!
  private let dismissThreshold: CGFloat = 44.0 * UIScreen.main.nativeScale
  private var dismissFeedbackTriggered = false

  private var disposeBag = Set<AnyCancellable>()
  private var playingProgressSubscriber: AnyCancellable?
  private var currentChapterSubscriber: AnyCancellable?

  /// Reference to displayed alert, to update the message label with the ongoing timer
  weak var sleepTimerAlert: UIAlertController?

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

    setupToolbar()

    setupGestures()

    bindGeneralObservers()

    bindPresenterEvents()

    bindProgressObservers()

    bindPlaybackControlsObservers()

    bindBookPlayingProgressEvents()

    bindTimerObserver()

    self.containerItemStackView.setCustomSpacing(26, after: self.artworkControl)
    toggleArtwork(for: traitCollection)
  }

  override func willTransition(
    to newCollection: UITraitCollection,
    with coordinator: UIViewControllerTransitionCoordinator
  ) {
    super.willTransition(to: newCollection, with: coordinator)

    coordinator.animate { [weak self] _ in
      self?.toggleArtwork(for: newCollection)
    }
  }

  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)

    /// Patch to fix background layers on default artwork for iPad
    if UIDevice.current.userInterfaceIdiom != .phone,
       artworkControl.artworkImage.isHidden {
      artworkControl.setupGradients(with: size)
    }
  }

  /// When the device has a compact vertical size class, there's not enough room to display the artwork
  func toggleArtwork(for trait: UITraitCollection) {
    if trait.verticalSizeClass == .compact {
      artworkControl.alpha = 0
      artworkControl.isHidden = true
    } else {
      artworkControl.alpha = 1
      artworkControl.isHidden = false
    }
  }

  // Prevents dragging the view down from changing the safeAreaInsets.top and .bottom
  // Note: I'm pretty sure there is a better solution for this that I haven't found yet - @pichfl
  override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()

    let window = UIApplication.shared.windows[0]
    let insets: UIEdgeInsets = window.safeAreaInsets

    self.closeButtonTop.constant = self.view.safeAreaInsets.top == 0.0 ? insets.top : 0
    self.toolbarBottomConstraint.constant = self.view.safeAreaInsets.bottom == 0.0 ? insets.bottom : 0
  }

  func setup() {
    self.closeButton.accessibilityLabel = "voiceover_dismiss_player_title".localized

    self.chapterTitleButton.titleLabel?.numberOfLines = 2
    self.chapterTitleButton.titleLabel?.textAlignment = .center
    self.chapterTitleButton.titleLabel?.lineBreakMode = .byWordWrapping
    self.chapterTitleButton.isAccessibilityElement = false

    // Based on Apple books, the player controls are kept the same for right-to-left languages
    self.progressSlider.semanticContentAttribute = .forceLeftToRight
    self.containerPlayerControlsStackView.semanticContentAttribute = .forceLeftToRight
    self.containerChapterControlsStackView.semanticContentAttribute = .forceLeftToRight
    self.containerProgressControlsStackView.semanticContentAttribute = .forceLeftToRight
  }

  func setupPlayerView(with currentItem: PlayableItem) {
    self.artworkControl.setupInfo(
      with: currentItem.title,
      author: currentItem.author
    )

    self.updateView(with: self.viewModel.getCurrentProgressState(currentItem))

    applyTheme(self.themeProvider.currentTheme)

    // Solution thanks to https://forums.developer.apple.com/thread/63166#180445
    self.modalPresentationCapturesStatusBarAppearance = true

    self.setNeedsStatusBarAppearanceUpdate()
  }

  func updateView(with progressObject: ProgressObject, shouldSetSliderValue: Bool = true) {
    if shouldSetSliderValue && self.progressSlider.isTracking { return }

    self.currentTimeLabel.text = progressObject.formattedCurrentTime
    self.currentTimeLabel.accessibilityLabel = String(
      describing: String.localizedStringWithFormat(self.viewModel.getCurrentTimeVoiceOverPrefix(),
                                                   VoiceOverService.secondsToMinutes(progressObject.currentTime))
    )

    if let progress = progressObject.progress {
      self.progressButton.setTitle(progress, for: .normal)
    }

    if let maxTime = progressObject.maxTime,
       let formattedMaxTime = progressObject.formattedMaxTime {
      self.maxTimeButton.setTitle(formattedMaxTime, for: .normal)
      self.maxTimeButton.accessibilityLabel = String(
        describing: "\(self.viewModel.getMaxTimeVoiceOverPrefix()) \(VoiceOverService.secondsToMinutes(maxTime))"
      )
    }

    self.chapterTitleButton.setTitle(progressObject.chapterTitle, for: .normal)

    if shouldSetSliderValue {
      self.progressSlider.setProgress(progressObject.sliderValue)
    }

    let leftChevron = UIImage(
      systemName: progressObject.prevChapterImageName,
      withConfiguration: UIImage.SymbolConfiguration(pointSize: 18,
                                                     weight: .semibold)
    )
    let rightChevron = UIImage(
      systemName: progressObject.nextChapterImageName,
      withConfiguration: UIImage.SymbolConfiguration(pointSize: 18,
                                                     weight: .semibold)
    )

    self.previousChapterButton.setImage(leftChevron, for: .normal)
    self.nextChapterButton.setImage(rightChevron, for: .normal)
  }
}

// MARK: - Observers
extension PlayerViewController {
  func bindProgressObservers() {
    self.progressSlider.publisher(for: .touchDown)
      .sink { [weak self] _ in
        // Disable recurring playback time events
        self?.playingProgressSubscriber?.cancel()

        self?.viewModel.handleSliderDownEvent()
      }.store(in: &disposeBag)

    self.progressSlider.publisher(for: .touchUpInside)
      .merge(with: self.progressSlider.publisher(for: .touchUpOutside))
      .sink { [weak self] sender in
        guard let slider = sender as? UISlider else { return }

        self?.viewModel.handleSliderUpEvent(with: slider.value)
        // Enable back recurring playback time events after one second
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
          self?.bindBookPlayingProgressEvents()
        }
      }.store(in: &disposeBag)

    self.progressSlider.publisher(for: .valueChanged)
      .sink { [weak self] sender in
        guard let self = self,
              let slider = sender as? UISlider else { return }
        self.progressSlider.setNeedsDisplay()

        let progressObject = self.viewModel.processSliderValueChangedEvent(with: slider.value)

        self.updateView(with: progressObject, shouldSetSliderValue: false)
      }.store(in: &disposeBag)
  }

  func bindBookPlayingProgressEvents() {
    self.playingProgressSubscriber?.cancel()
    self.playingProgressSubscriber = NotificationCenter.default.publisher(for: .bookPlaying)
      .sink { [weak self] _ in
        guard let self = self else { return }
        self.updateView(with: self.viewModel.getCurrentProgressState())
      }
  }

  func bindPlaybackControlsObservers() {
    self.viewModel.isPlayingObserver()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] isPlaying in
        self?.playIconView.isPlaying = isPlaying
      }
      .store(in: &disposeBag)

    self.maxTimeButton.publisher(for: .touchUpInside)
      .sink { [weak self] _ in
        guard let self = self,
              !self.progressSlider.isTracking else { return }

        let progressObject = self.viewModel.processToggleMaxTime()

        self.updateView(with: progressObject)
      }.store(in: &disposeBag)

    self.progressButton.publisher(for: .touchUpInside)
      .merge(with: self.chapterTitleButton.publisher(for: .touchUpInside))
      .sink { [weak self] _ in
        guard let self = self,
              !self.progressSlider.isTracking else { return }

        let progressObject = self.viewModel.processToggleProgressState()

        self.updateView(with: progressObject)
      }.store(in: &disposeBag)

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

    self.previousChapterButton.publisher(for: .touchUpInside)
      .sink { [weak self] _ in
        self?.viewModel.handlePreviousChapterAction()
      }
      .store(in: &disposeBag)

    self.nextChapterButton.publisher(for: .touchUpInside)
      .sink { [weak self] _ in
        self?.viewModel.handleNextChapterAction()
      }
      .store(in: &disposeBag)
  }

  func bindTimerObserver() {
    viewModel.toolbarSleepDescriptionPublisher().sink { [weak self] toolbarDescription in
      guard let self else { return }

      self.sleepLabel.title = toolbarDescription

      if let timeFormatted = toolbarDescription {
        self.sleepLabel.isAccessibilityElement = true
        let remainingTitle = String(describing: String.localizedStringWithFormat("sleep_remaining_title".localized, timeFormatted))
        self.sleepLabel.accessibilityLabel = String(describing: remainingTitle)

        if let items = self.bottomToolbar.items,
           !items.contains(self.sleepLabel) {
          self.updateToolbar(true, animated: true)
        }
      } else {
        self.sleepLabel.isAccessibilityElement = false

        if let items = self.bottomToolbar.items,
           items.contains(self.sleepLabel) {
          self.updateToolbar(false, animated: true)
        }
      }
    }.store(in: &disposeBag)

    viewModel.sleepAlertMessagePublisher().sink { [weak self] alertMessage in
      self?.sleepTimerAlert?.message = alertMessage
    }.store(in: &disposeBag)
  }

  func bindGeneralObservers() {
    NotificationCenter.default.publisher(for: .requestReview)
      .debounce(for: 1.0, scheduler: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.viewModel.requestReview()
      }
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .bookEnd)
      .debounce(for: 1.0, scheduler: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.viewModel.requestReview()
      }
      .store(in: &disposeBag)

    self.closeButton.publisher(for: .touchUpInside)
      .sink { [weak self] _ in
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        self?.viewModel.dismiss()
      }
      .store(in: &disposeBag)

    self.viewModel.currentItemObserver()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] item in
        self?.currentChapterSubscriber?.cancel()
        guard let self = self,
              let item = item else { return }

        self.setupPlayerView(with: item)
        self.bindCurrentChapterObserver(for: item)
    }.store(in: &disposeBag)

    self.viewModel.currentSpeedObserver()
      .removeDuplicates()
      .sink { [weak self] speed in
      guard let self = self else { return }

      self.speedButton.title = self.formatSpeed(speed)
      self.speedButton.accessibilityLabel = String(describing: self.formatSpeed(speed) + " \("speed_title".localized)")

      // Only update progress if the player is in pause state
      guard !self.playIconView.isPlaying else { return }

      let progressObject = self.viewModel.getCurrentProgressState()

      self.updateView(with: progressObject)
    }.store(in: &disposeBag)
  }

  func bindCurrentChapterObserver(for item: PlayableItem) {
    currentChapterSubscriber = item.$currentChapter.sink { [weak self, item] chapter in
      let relativePath: String

      if let chapter,
         ArtworkService.isCached(relativePath: chapter.relativePath) {
        relativePath = chapter.relativePath
      } else {
        relativePath = item.relativePath
      }

      self?.artworkControl.setupArtworkImage(relativePath: relativePath)
    }
  }

  func bindPresenterEvents() {
    self.viewModel.eventsPublisher
      .sink { [weak self] event in
        switch event {
        case .sleepTimerAlert(let content):
          self?.presentSleepTimerAlert(content)
        case .customSleepTimer(let title):
          self?.presentCustomSleepTimerAlert(title)
        }
      }.store(in: &disposeBag)
  }
}

// MARK: - Toolbar
extension PlayerViewController {
  func setupToolbar() {
    self.bottomToolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
    self.bottomToolbar.setShadowImage(UIImage(), forToolbarPosition: .any)
    self.speedButton.setTitleTextAttributes([NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18.0, weight: .semibold)], for: .normal)
    self.previousChapterButton.accessibilityLabel = "chapters_previous_title".localized
    self.nextChapterButton.accessibilityLabel = "chapters_next_title".localized
    self.bookmarkButton.accessibilityLabel = "bookmark_create_title".localized
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

    items.append(spacer)
    items.append(self.bookmarkButton)

    items.append(spacer)
    items.append(self.listButton)

    items.append(spacer)
    items.append(self.moreButton)

    self.bottomToolbar.setItems(items, animated: animated)
  }
}

// MARK: - Toolbar Actions

extension PlayerViewController {
  @IBAction func showList(_ sender: UIBarButtonItem) {
    self.viewModel.showList()
  }

  @IBAction func createBookmark(_ sender: UIBarButtonItem) {
    self.viewModel.createBookmark(vc: self)
  }

  @IBAction func setSpeed() {
    self.viewModel.showControls()
  }

  @IBAction func setSleepTimer() {
    self.viewModel.showSleepTimerActions()
  }

  func presentSleepTimerAlert(_ content: BPAlertContent) {
    let alert = buildAlert(content)
    sleepTimerAlert = alert

    alert.popoverPresentationController?.permittedArrowDirections = .any
    alert.popoverPresentationController?.barButtonItem = sleepButton

    present(alert, animated: true, completion: nil)
  }

  func presentCustomSleepTimerAlert(_ title: String) {
    let customTimerAlert = UIAlertController(
      title: title,
      message: "\n\n\n\n\n\n\n\n\n\n",
      preferredStyle: .actionSheet
    )

    let datePicker = UIDatePicker()
    datePicker.datePickerMode = .countDownTimer
    if let customTimerDuration = viewModel.getLastCustomSleepTimerDuration() {
      datePicker.countDownDuration = customTimerDuration
    }
    customTimerAlert.view.addSubview(datePicker)
    customTimerAlert.addAction(
      UIAlertAction(
        title: "ok_button".localized,
        style: .default,
        handler: { [weak self] _ in
          self?.viewModel.handleCustomSleepTimerOption(seconds: datePicker.countDownDuration)
        }
      )
    )
    customTimerAlert.addAction(
      UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil)
    )

    datePicker.translatesAutoresizingMaskIntoConstraints = false
    datePicker.widthAnchor.constraint(
      equalTo: datePicker.superview!.widthAnchor
    ).isActive = true
    datePicker.topAnchor.constraint(
      equalTo: datePicker.superview!.topAnchor,
      constant: 30
    ).isActive = true

    customTimerAlert.popoverPresentationController?.barButtonItem = sleepButton

    present(customTimerAlert, animated: true, completion: nil)
  }

  @IBAction func showMore() {
    guard self.viewModel.hasLoadedBook() else {
      return
    }

    let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

    actionSheet.addAction(UIAlertAction(
      title: self.viewModel.getListTitleForMoreAction(),
      style: .default,
      handler: { [weak self] _ in
        self?.viewModel.showListFromMoreAction()
    }))

    actionSheet.addAction(UIAlertAction(title: "jump_start_title".localized, style: .default, handler: { [weak self] _ in
      self?.viewModel.handleJumpToStart()
    }))

    let markTitle = self.viewModel.isBookFinished() ? "mark_unfinished_title".localized : "mark_finished_title".localized

    actionSheet.addAction(UIAlertAction(title: markTitle, style: .default, handler: { [weak self] _ in
      self?.viewModel.handleMarkCompletion()
    }))

    actionSheet.addAction(UIAlertAction(
      title: "button_free_title".localized,
      style: .default,
      handler: { [weak self] _ in
        self?.viewModel.showButtonFree()
    }))

    actionSheet.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))

    if let popoverPresentationController = actionSheet.popoverPresentationController {
      popoverPresentationController.barButtonItem = moreButton
    }

    self.present(actionSheet, animated: true, completion: nil)
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
        self.viewModel.dismiss()
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
  func applyTheme(_ theme: SimpleTheme) {
    self.themedStatusBarStyle = theme.useDarkVariant
    ? .lightContent
    : .default
    setNeedsStatusBarAppearanceUpdate()

    self.view.backgroundColor = theme.systemBackgroundColor
    self.bottomToolbar.tintColor = theme.secondaryColor
    self.closeButton.tintColor = theme.linkColor

    self.progressSlider.tintColor = theme.linkColor
    self.progressSlider.minimumTrackTintColor = theme.linkColor
    self.progressSlider.maximumTrackTintColor = theme.linkColor.withAlpha(newAlpha: 0.3)

    self.currentTimeLabel.textColor = theme.secondaryColor
    self.maxTimeButton.setTitleColor(theme.secondaryColor, for: .normal)
    self.progressButton.setTitleColor(theme.secondaryColor, for: .normal)
    self.chapterTitleButton.setTitleColor(theme.primaryColor, for: .normal)
    self.previousChapterButton.tintColor = theme.primaryColor
    self.nextChapterButton.tintColor = theme.primaryColor
  }
}
