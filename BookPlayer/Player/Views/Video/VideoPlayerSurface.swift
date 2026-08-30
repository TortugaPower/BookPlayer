//
//  VideoPlayerSurface.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 15/7/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import SwiftUI
import UIKit

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
  /// Whether this surface's layer backs the system Picture in Picture window
  /// (only the player screen's inline surface should)
  private let hostsPictureInPicture: Bool
  private let backgroundVideoView = PlayerLayerView()
  private let foregroundVideoView = PlayerLayerView()
  private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))

  private var lifecycleObservers = [NSObjectProtocol]()
  private weak var attachedPlayer: AVPlayer?

  init(showsBlurredBackground: Bool, hostsPictureInPicture: Bool = false) {
    self.showsBlurredBackground = showsBlurredBackground
    self.hostsPictureInPicture = hostsPictureInPicture
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

    if hostsPictureInPicture {
      if player != nil {
        VideoPiPCoordinator.shared.host(playerLayer: foregroundVideoView.playerLayer)
      } else {
        VideoPiPCoordinator.shared.release(playerLayer: foregroundVideoView.playerLayer)
      }
    }
  }

  /// Force the layers to re-associate with the attached player. Setting the same
  /// `AVPlayer` on another `AVPlayerLayer` (the fullscreen surface) stops this layer
  /// from rendering even though its `player` reference is left untouched — so a plain
  /// `connectLayers` is a no-op here (identity guard). Detaching and reattaching is
  /// what reclaims the video output.
  private func reclaimVideoRendering() {
    guard let player = attachedPlayer else { return }

    foregroundVideoView.playerLayer.player = nil
    foregroundVideoView.playerLayer.player = player
    if showsBlurredBackground {
      backgroundVideoView.playerLayer.player = nil
      backgroundVideoView.playerLayer.player = player
    }
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
  /// moves to the background. Detaching the layers while backgrounded keeps the audio
  /// playing — a video always continues as audio in the background, like any other item.
  private func registerLifecycleObservers() {
    let center = NotificationCenter.default

    lifecycleObservers.append(
      center.addObserver(
        forName: UIApplication.didEnterBackgroundNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        guard let self else { return }

        /// Leave the layers connected when PiP is taking over this surface —
        /// detaching here would cancel the automatic PiP start
        if self.hostsPictureInPicture,
           VideoPiPCoordinator.shared.isEnabled,
           self.attachedPlayer?.timeControlStatus != .paused {
          return
        }

        self.connectLayers(to: nil)
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

    /// Returning from fullscreen: the fullscreen surface had taken over this player's
    /// video output, so reclaim it (a no-op for the torn-down fullscreen surface,
    /// whose player was already detached).
    lifecycleObservers.append(
      center.addObserver(
        forName: .videoFullscreenDidDismiss,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.reclaimVideoRendering()
      }
    )
  }
}

struct VideoPlayerSurface: UIViewRepresentable {
  let player: AVPlayer
  var showsBlurredBackground = true
  var hostsPictureInPicture = false

  func makeUIView(context: Context) -> VideoSurfaceUIView {
    let view = VideoSurfaceUIView(
      showsBlurredBackground: showsBlurredBackground,
      hostsPictureInPicture: hostsPictureInPicture
    )
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
