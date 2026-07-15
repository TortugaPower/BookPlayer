//
//  VideoPlayerView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 15/7/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import BookPlayerKit
import SwiftUI
import UIKit

// MARK: - Video surface

/// UIView backed by an `AVPlayerLayer`. Using the backing layer (instead of a
/// manually laid-out sublayer) lets UIView animations resize the video smoothly
/// during the fullscreen transition.
private final class PlayerLayerView: UIView {
  override class var layerClass: AnyClass { AVPlayerLayer.self }

  // swiftlint:disable:next force_cast
  var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

/// Renders the shared player's video tracks: an aspect-fit layer on top, over an
/// aspect-fill layer blurred to cover the container's empty space.
final class VideoSurfaceUIView: UIView {
  private let showsBlurredBackground: Bool
  private let backgroundVideoView = PlayerLayerView()
  private let foregroundVideoView = PlayerLayerView()
  private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))

  private var lifecycleObservers = [NSObjectProtocol]()
  private weak var attachedPlayer: AVPlayer?

  init(showsBlurredBackground: Bool) {
    self.showsBlurredBackground = showsBlurredBackground
    super.init(frame: .zero)

    backgroundColor = .black

    if showsBlurredBackground {
      backgroundVideoView.playerLayer.videoGravity = .resizeAspectFill
      addPinnedSubview(backgroundVideoView)
      addPinnedSubview(blurView)
    }

    foregroundVideoView.playerLayer.videoGravity = .resizeAspect
    addPinnedSubview(foregroundVideoView)

    registerLifecycleObservers()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    lifecycleObservers.forEach(NotificationCenter.default.removeObserver)
  }

  private func addPinnedSubview(_ subview: UIView) {
    subview.frame = bounds
    subview.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(subview)
  }

  func attach(_ player: AVPlayer?) {
    attachedPlayer = player
    connectLayers(to: player)
  }

  private func connectLayers(to player: AVPlayer?) {
    if foregroundVideoView.playerLayer.player !== player {
      foregroundVideoView.playerLayer.player = player
    }
    if showsBlurredBackground, backgroundVideoView.playerLayer.player !== player {
      backgroundVideoView.playerLayer.player = player
    }
  }

  /// A player rendering video through a layer is paused by the system when the app
  /// moves to the background. Detaching the layers while backgrounded keeps the
  /// audio playing (opt-out via the settings toggle).
  private func registerLifecycleObservers() {
    let center = NotificationCenter.default

    lifecycleObservers.append(
      center.addObserver(
        forName: UIApplication.didEnterBackgroundNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        guard
          UserDefaults.standard.bool(forKey: Constants.UserDefaults.videoBackgroundPlaybackEnabled)
        else { return }

        self?.connectLayers(to: nil)
      }
    )

    lifecycleObservers.append(
      center.addObserver(
        forName: UIApplication.willEnterForegroundNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        guard let self else { return }

        self.connectLayers(to: self.attachedPlayer)
      }
    )
  }
}

struct VideoPlayerSurface: UIViewRepresentable {
  let player: AVPlayer
  var showsBlurredBackground = true

  func makeUIView(context: Context) -> VideoSurfaceUIView {
    let view = VideoSurfaceUIView(showsBlurredBackground: showsBlurredBackground)
    view.attach(player)
    return view
  }

  func updateUIView(_ uiView: VideoSurfaceUIView, context: Context) {
    /// The player instance can be recreated after a media-services reset
    uiView.attach(player)
  }

  static func dismantleUIView(_ uiView: VideoSurfaceUIView, coordinator: ()) {
    uiView.attach(nil)
  }
}

// MARK: - Artwork replacement

/// Takes the artwork's place in the player screen when the current chapter is a video
struct VideoArtworkView: View {
  let player: AVPlayer
  /// Receives the container's frame in global coordinates, so the fullscreen
  /// transition can animate from the video's exact on-screen position
  let onFullscreenTap: (CGRect) -> Void

  @State private var containerFrame: CGRect = .zero
  @State private var controlsVisible = true

  var body: some View {
    ZStack {
      // 1. Create the square "box"
      Color.clear
        .aspectRatio(1, contentMode: .fit)

      VideoPlayerSurface(player: player)
        .contentShape(Rectangle())
        .onTapGesture {
          withAnimation(.easeInOut(duration: 0.2)) {
            controlsVisible.toggle()
          }
        }

      VStack {
        HStack(spacing: 12) {
          Spacer()

          Button {
            onFullscreenTap(containerFrame)
          } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 20, height: 20)
              .foregroundColor(.white)
              .frame(width: 44, height: 44) // Standard touch target size
              .contentShape(Rectangle())
          }
          .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
          .accessibilityLabel(Text("video_fullscreen_title".localized))

          AirplayPicker()
            .frame(width: 44, height: 44) // Standard touch target size
            .padding(.trailing, 5)
            .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("audio_source_title"))
        }
        .padding(.top, 5)
        .frame(maxWidth: .infinity)

        Spacer()
      }
      .opacity(controlsVisible ? 1 : 0)
      .allowsHitTesting(controlsVisible)
    }
    .aspectRatio(1, contentMode: .fit)
    .cornerRadius(12)
    .clipped()
    .background(
      GeometryReader { geometry in
        Color.clear
          .onAppear {
            containerFrame = geometry.frame(in: .global)
          }
          .onChange(of: geometry.frame(in: .global)) { _, newFrame in
            containerFrame = newFrame
          }
      }
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Fullscreen

/// YouTube-style fullscreen: the surface animates from its inline frame into a
/// 90°-rotated fullscreen layout via a transform. The interface orientation never
/// changes, so the transition is one continuous turn and works regardless of the
/// device's rotation lock. When the interface is already landscape, the surface
/// just expands without rotating.
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
  /// Freeze the interface orientation while the transform-based layout is up
  private let lockedOrientations: UIInterfaceOrientationMask

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

  private func animateIn() {
    guard !hasAnimatedIn else { return }
    hasAnimatedIn = true

    let bounds = view.bounds
    let rotates = bounds.height > bounds.width

    UIView.animate(
      withDuration: 0.5,
      delay: 0,
      usingSpringWithDamping: 0.85,
      initialSpringVelocity: 0
    ) {
      self.dimView.alpha = 1
      self.closeButton.alpha = 1
      self.playPauseButton.alpha = 1
      self.contentContainer.layer.cornerRadius = 0

      if rotates {
        self.contentContainer.transform = CGAffineTransform(rotationAngle: .pi / 2)
        self.contentContainer.bounds = CGRect(x: 0, y: 0, width: bounds.height, height: bounds.width)
      } else {
        self.contentContainer.bounds = CGRect(origin: .zero, size: bounds.size)
      }
      self.contentContainer.center = CGPoint(x: bounds.midX, y: bounds.midY)
      self.contentContainer.layoutIfNeeded()
    }
  }

  @objc private func close() {
    UIView.animate(
      withDuration: 0.4,
      delay: 0,
      usingSpringWithDamping: 0.9,
      initialSpringVelocity: 0
    ) {
      self.dimView.alpha = 0
      self.closeButton.alpha = 0
      self.playPauseButton.alpha = 0
      self.contentContainer.transform = .identity
      self.contentContainer.bounds = CGRect(origin: .zero, size: self.sourceFrame.size)
      self.contentContainer.center = CGPoint(x: self.sourceFrame.midX, y: self.sourceFrame.midY)
      self.contentContainer.layer.cornerRadius = 12
      self.contentContainer.layoutIfNeeded()
    } completion: { _ in
      /// Detach only after the view is off screen — detaching first leaves the
      /// still-visible surface rendering an empty (black) frame for a beat
      self.dismiss(animated: false) {
        self.surface.attach(nil)
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
