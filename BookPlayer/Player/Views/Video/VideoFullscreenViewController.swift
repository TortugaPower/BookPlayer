//
//  VideoFullscreenViewController.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 15/7/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import BookPlayerKit
import UIKit

/// YouTube-style fullscreen: the system rotation to landscape IS the entry animation —
/// the container expands from the video's inline frame alongside the interface
/// rotation, so the turn, the home indicator relocation, and the safe-area change all
/// happen as one continuous motion. Closing rides the rotation back to portrait the
/// same way. When the interface is already landscape, the surface just expands in place.
final class VideoFullscreenViewController: UIViewController {
  private let player: AVPlayer
  private let sourceFrame: CGRect
  private let onPlayPause: () -> Void
  /// Rotating container: holds the surface AND the controls, so buttons live in
  /// the video's coordinate space and land in the right corners when the phone
  /// is held horizontally
  private let contentContainer = UIView()
  private let surface = VideoSurfaceUIView(showsBlurredBackground: true)
  private let dimView = UIView()
  private let closeButton = UIButton(type: .system)
  private let playPauseButton = UIButton(type: .system)
  private var timeControlObservation: NSKeyValueObservation?
  private var controlsVisible = true
  private var hasAnimatedIn = false

  /// Directs what `viewWillTransition` animates alongside the system rotation
  private enum TransitionPhase {
    /// Rotating to landscape: expand the container from the inline frame
    case entering
    /// Rotating back to portrait: shrink the container into the inline frame, then dismiss
    case closing
    case none
  }

  private var phase = TransitionPhase.none
  /// Interface orientations the controller allows at the moment; driven by the
  /// enter/close flow via `setNeedsUpdateOfSupportedInterfaceOrientations`
  private var lockedOrientations: UIInterfaceOrientationMask

  init(player: AVPlayer, sourceFrame: CGRect, onPlayPause: @escaping () -> Void) {
    self.player = player
    self.sourceFrame = sourceFrame
    self.onPlayPause = onPlayPause

    switch WindowHelper.activeWindow?.windowScene?.interfaceOrientation {
    case .landscapeLeft:
      self.lockedOrientations = .landscapeLeft
    case .landscapeRight:
      self.lockedOrientations = .landscapeRight
    case .portraitUpsideDown:
      self.lockedOrientations = .portraitUpsideDown
    default:
      self.lockedOrientations = .portrait
    }

    super.init(nibName: nil, bundle: nil)

    modalPresentationStyle = .overFullScreen
    modalPresentationCapturesStatusBarAppearance = true
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var supportedInterfaceOrientations: UIInterfaceOrientationMask { lockedOrientations }
  override var prefersStatusBarHidden: Bool { true }
  override var prefersHomeIndicatorAutoHidden: Bool { true }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .clear

    dimView.backgroundColor = .black
    dimView.alpha = 0
    dimView.frame = view.bounds
    dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(dimView)

    contentContainer.bounds = CGRect(origin: .zero, size: sourceFrame.size)
    contentContainer.center = CGPoint(x: sourceFrame.midX, y: sourceFrame.midY)
    contentContainer.layer.cornerRadius = 12
    contentContainer.layer.masksToBounds = true
    view.addSubview(contentContainer)

    surface.attach(player)
    surface.frame = contentContainer.bounds
    surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    contentContainer.addSubview(surface)

    var buttonConfiguration = UIButton.Configuration.plain()
    buttonConfiguration.image = UIImage(
      systemName: "xmark",
      withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
    )
    buttonConfiguration.baseForegroundColor = .white
    closeButton.configuration = buttonConfiguration
    closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.4)
    closeButton.layer.cornerRadius = 22
    closeButton.alpha = 0
    closeButton.accessibilityLabel = "done_title".localized
    closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
    closeButton.translatesAutoresizingMaskIntoConstraints = false
    contentContainer.addSubview(closeButton)

    var playPauseConfiguration = UIButton.Configuration.plain()
    playPauseConfiguration.baseForegroundColor = .white
    playPauseButton.configuration = playPauseConfiguration
    playPauseButton.backgroundColor = UIColor.black.withAlphaComponent(0.4)
    playPauseButton.layer.cornerRadius = 36
    playPauseButton.alpha = 0
    playPauseButton.addTarget(self, action: #selector(togglePlayPause), for: .touchUpInside)
    playPauseButton.translatesAutoresizingMaskIntoConstraints = false
    contentContainer.addSubview(playPauseButton)

    /// Constraints are relative to the rotating container, so "top trailing" is the
    /// video's top-right corner regardless of how the content is turned. The inset
    /// is generous enough to clear the notch/home indicator, which end up on the
    /// container's leading/trailing edges once rotated.
    NSLayoutConstraint.activate([
      closeButton.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -40),
      closeButton.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 16),
      closeButton.widthAnchor.constraint(equalToConstant: 44),
      closeButton.heightAnchor.constraint(equalToConstant: 44),
      playPauseButton.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
      playPauseButton.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor),
      playPauseButton.widthAnchor.constraint(equalToConstant: 72),
      playPauseButton.heightAnchor.constraint(equalToConstant: 72),
    ])

    /// Keep the play/pause icon in sync with the actual playback state
    timeControlObservation = player.observe(\.timeControlStatus, options: [.initial]) { [weak self] _, _ in
      DispatchQueue.main.async {
        self?.updatePlayPauseIcon()
      }
    }

    let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(toggleControls))
    tapRecognizer.cancelsTouchesInView = false
    tapRecognizer.delegate = self
    view.addGestureRecognizer(tapRecognizer)
  }

  private func updatePlayPauseIcon() {
    let isPlaying = player.timeControlStatus != .paused
    playPauseButton.configuration?.image = UIImage(
      systemName: isPlaying ? "pause.fill" : "play.fill",
      withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
    )
    playPauseButton.accessibilityLabel = isPlaying
      ? "pause_title".localized
      : "play_title".localized
  }

  @objc private func togglePlayPause() {
    onPlayPause()
  }

  @objc private func toggleControls() {
    controlsVisible.toggle()

    UIView.animate(withDuration: 0.2) {
      self.closeButton.alpha = self.controlsVisible ? 1 : 0
      self.playPauseButton.alpha = self.controlsVisible ? 1 : 0
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    setNeedsStatusBarAppearanceUpdate()
    animateIn()
  }

  /// The entry animation rides the system rotation: request landscape and expand the
  /// container from the inline frame alongside the rotation, so the turn and the
  /// home-indicator/safe-area relocation happen as one continuous motion
  private func animateIn() {
    guard !hasAnimatedIn else { return }
    hasAnimatedIn = true

    let entersFromPortrait = view.bounds.height > view.bounds.width

    if entersFromPortrait, let windowScene = view.window?.windowScene {
      phase = .entering
      lockedOrientations = .landscapeRight
      setNeedsUpdateOfSupportedInterfaceOrientations()
      windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { _ in
        /// Rotation refused: fall back to expanding in place
        Task { @MainActor in
          self.phase = .none
          self.expandInPlace()
        }
      }
    } else {
      expandInPlace()
    }
  }

  /// No-rotation entry (interface already landscape, or the rotation was refused)
  private func expandInPlace() {
    UIView.animate(
      withDuration: 0.5,
      delay: 0,
      usingSpringWithDamping: 0.85,
      initialSpringVelocity: 0
    ) {
      self.applyFullscreenLayout(for: self.view.bounds.size)
      self.contentContainer.layoutIfNeeded()
    }
  }

  private func applyFullscreenLayout(for size: CGSize) {
    dimView.alpha = 1
    closeButton.alpha = 1
    playPauseButton.alpha = 1
    contentContainer.layer.cornerRadius = 0
    contentContainer.bounds = CGRect(origin: .zero, size: size)
    contentContainer.center = CGPoint(x: size.width / 2, y: size.height / 2)
  }

  private func applyInlineLayout() {
    dimView.alpha = 0
    closeButton.alpha = 0
    playPauseButton.alpha = 0
    contentContainer.layer.cornerRadius = 12
    contentContainer.bounds = CGRect(origin: .zero, size: sourceFrame.size)
    contentContainer.center = CGPoint(x: sourceFrame.midX, y: sourceFrame.midY)
  }

  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)

    switch phase {
    case .none:
      return
    case .entering:
      coordinator.animate(alongsideTransition: { _ in
        self.applyFullscreenLayout(for: size)
        self.contentContainer.layoutIfNeeded()
      }, completion: { _ in
        self.phase = .none
      })
    case .closing:
      coordinator.animate(alongsideTransition: { _ in
        self.applyInlineLayout()
        self.contentContainer.layoutIfNeeded()
      }, completion: { _ in
        self.phase = .none
        /// Detach only after the view is off screen — detaching first leaves the
        /// still-visible surface rendering an empty (black) frame for a beat
        self.dismiss(animated: false) {
          self.surface.attach(nil)
          NotificationCenter.default.post(name: .videoFullscreenDidDismiss, object: nil)
        }
      })
    }
  }

  @objc private func close() {
    /// If the entry rotated the interface, the exit rotation carries the shrink
    /// animation back to the inline frame (valid in portrait coordinates)
    if lockedOrientations == .landscapeRight,
       view.bounds.width > view.bounds.height,
       let windowScene = view.window?.windowScene {
      phase = .closing
      lockedOrientations = .portrait
      setNeedsUpdateOfSupportedInterfaceOrientations()
      windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { _ in
        Task { @MainActor in
          self.phase = .none
          self.animateOut()
        }
      }
    } else {
      animateOut()
    }
  }

  private func animateOut() {
    UIView.animate(
      withDuration: 0.4,
      delay: 0,
      usingSpringWithDamping: 0.9,
      initialSpringVelocity: 0
    ) {
      self.applyInlineLayout()
      self.contentContainer.layoutIfNeeded()
    } completion: { _ in
      /// Detach only after the view is off screen — detaching first leaves the
      /// still-visible surface rendering an empty (black) frame for a beat
      self.dismiss(animated: false) {
        self.surface.attach(nil)
        NotificationCenter.default.post(name: .videoFullscreenDidDismiss, object: nil)
      }
    }
  }
}

extension VideoFullscreenViewController: UIGestureRecognizerDelegate {
  /// Don't let the controls-toggle tap swallow touches meant for the buttons
  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldReceive touch: UITouch
  ) -> Bool {
    return !(touch.view is UIControl)
  }
}

@MainActor
enum VideoFullscreenPresenter {
  static func present(player: AVPlayer, from sourceFrame: CGRect, onPlayPause: @escaping () -> Void) {
    let fallbackWindow = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.windows.first }
      .first

    guard let root = (WindowHelper.activeWindow ?? fallbackWindow)?.rootViewController else {
      return
    }

    var topController = root
    while let presented = topController.presentedViewController {
      topController = presented
    }

    let controller = VideoFullscreenViewController(
      player: player,
      sourceFrame: sourceFrame,
      onPlayPause: onPlayPause
    )
    topController.present(controller, animated: false)
  }
}
