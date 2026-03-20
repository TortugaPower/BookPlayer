//
//  SlickSlider.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 12/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import BookPlayerKit

// MARK: - UISlider subclass for custom track height

class ThinTrackSlider: UISlider {
  var trackHeight: CGFloat = 4
  var thumbShadowColor: UIColor = .clear {
    didSet { updateThumbShadow() }
  }

  private let shadowLayer = CALayer()

  override init(frame: CGRect) {
    super.init(frame: frame)
    shadowLayer.shadowOffset = .zero
    shadowLayer.shadowRadius = 6
    shadowLayer.shadowOpacity = 1
    layer.insertSublayer(shadowLayer, at: 0)
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  override func trackRect(forBounds bounds: CGRect) -> CGRect {
    let center = bounds.midY
    return CGRect(
      x: bounds.minX,
      y: center - trackHeight / 2,
      width: bounds.width,
      height: trackHeight
    )
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let thumbFrame = thumbRect(
      forBounds: bounds,
      trackRect: trackRect(forBounds: bounds),
      value: value
    )
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    shadowLayer.frame = thumbFrame
    shadowLayer.shadowPath = UIBezierPath(ovalIn: thumbFrame.offsetBy(
      dx: -thumbFrame.origin.x,
      dy: -thumbFrame.origin.y
    )).cgPath
    CATransaction.commit()
  }

  private func updateThumbShadow() {
    shadowLayer.shadowColor = thumbShadowColor.cgColor
  }
}

// MARK: - SwiftUI wrapper

struct SlickSlider: UIViewRepresentable {
  @Binding var value: Double
  var range: ClosedRange<Double> = 0...100
  var onEditingChanged: (Bool) -> Void = { _ in }
  var onDragValueChanged: ((Double) -> Void)?
  var accentColor = Color(red: 0.35, green: 0.6, blue: 0.9)

  private let trackHeight: CGFloat = 4
  private let thumbSize: CGFloat = 18

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeUIView(context: Context) -> ThinTrackSlider {
    let slider = ThinTrackSlider()
    slider.trackHeight = trackHeight
    slider.minimumValue = Float(range.lowerBound)
    slider.maximumValue = Float(range.upperBound)
    slider.value = Float(value)
    slider.isContinuous = true

    let uiColor = UIColor(accentColor)
    slider.setMinimumTrackImage(
      Self.makeTrackImage(color: uiColor, height: trackHeight),
      for: .normal
    )
    slider.setMaximumTrackImage(
      Self.makeTrackImage(
        color: UIColor.secondaryLabel.withAlphaComponent(0.2),
        height: trackHeight
      ),
      for: .normal
    )
    slider.setThumbImage(
      Self.makeThumbImage(size: thumbSize, color: uiColor),
      for: .normal
    )
    slider.thumbShadowColor = uiColor.withAlphaComponent(0.6)

    slider.addTarget(
      context.coordinator,
      action: #selector(Coordinator.valueChanged(_:event:)),
      for: .valueChanged
    )

    return slider
  }

  func updateUIView(_ slider: ThinTrackSlider, context: Context) {
    if !context.coordinator.isDragging {
      slider.value = Float(value)
    }

    let uiColor = UIColor(accentColor)
    if context.coordinator.cachedAccentColor != uiColor {
      context.coordinator.cachedAccentColor = uiColor
      slider.setMinimumTrackImage(
        Self.makeTrackImage(color: uiColor, height: trackHeight),
        for: .normal
      )
      slider.setMaximumTrackImage(
        Self.makeTrackImage(
          color: UIColor.secondaryLabel.withAlphaComponent(0.2),
          height: trackHeight
        ),
        for: .normal
      )
      slider.setThumbImage(
        Self.makeThumbImage(size: thumbSize, color: uiColor),
        for: .normal
      )
      slider.thumbShadowColor = uiColor.withAlphaComponent(0.6)
    }
  }

  private static func makeThumbImage(size: CGFloat, color: UIColor) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
    return renderer.image { ctx in
      color.setFill()
      ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
    }
  }

  private static func makeTrackImage(color: UIColor, height: CGFloat) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: height, height: height))
    let image = renderer.image { ctx in
      let rect = CGRect(x: 0, y: 0, width: height, height: height)
      let path = UIBezierPath(roundedRect: rect, cornerRadius: height / 2)
      color.setFill()
      path.fill()
    }
    let capInset = height / 2
    return image.resizableImage(withCapInsets: UIEdgeInsets(
      top: 0, left: capInset, bottom: 0, right: capInset
    ), resizingMode: .stretch)
  }

  // MARK: - Coordinator

  class Coordinator: NSObject {
    var parent: SlickSlider
    var isDragging = false
    var cachedAccentColor: UIColor?

    init(_ parent: SlickSlider) {
      self.parent = parent
    }

    @objc func valueChanged(_ slider: UISlider, event: UIEvent) {
      let value = Double(slider.value)

      if let touch = event.allTouches?.first {
        switch touch.phase {
        case .began:
          isDragging = true
          parent.onEditingChanged(true)
          parent.onDragValueChanged?(value)
        case .moved:
          parent.onDragValueChanged?(value)
        case .ended, .cancelled:
          parent.value = value
          parent.onEditingChanged(false)
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isDragging = false
          }
        default:
          break
        }
      } else {
        // VoiceOver adjustments have no touch event
        parent.value = value
        parent.onDragValueChanged?(value)
        parent.onEditingChanged(false)
      }
    }
  }
}

// MARK: - Accessibility

extension ThinTrackSlider {
  override func accessibilityIncrement() {
    value = min(value + accessibilityStep, maximumValue)
    sendActions(for: .valueChanged)
  }

  override func accessibilityDecrement() {
    value = max(value - accessibilityStep, minimumValue)
    sendActions(for: .valueChanged)
  }

  private var accessibilityStep: Float {
    (maximumValue - minimumValue) * 0.01
  }

  override var accessibilityValue: String? {
    get {
      let range = Double(maximumValue - minimumValue)
      let percent = range == 0 ? 0 : Int(((Double(value - minimumValue) / range) * 100).rounded(.up))
      return String.localizedStringWithFormat("progress_complete_description".localized, percent)
    }
    set {}
  }
}

#Preview {
  SlickSlider(value: .constant(0.4))
}
