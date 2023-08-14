//
//  ArtworkView.swift
//  BookPlayer
//
//  Created by Florian Pichler on 22.06.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import AVKit
import BookPlayerKit
import UIKit
import Themeable

class ArtworkControl: UIView, UIGestureRecognizerDelegate {
  @IBOutlet var contentView: UIView!

  @IBOutlet weak var artworkImage: BPArtworkView!
  @IBOutlet weak var artworkOverlay: UIView!
  @IBOutlet weak var backgroundGradientColorView: UIView!
  @IBOutlet weak var authorLabel: UILabel!
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var infoContainerStackView: UIStackView!
  @IBOutlet weak var airplayView: UIView!

  private var leftGradientLayer = CAGradientLayer()
  private var rightGradientLayer = CAGradientLayer()

  var shadowOpacity: CGFloat {
    get {
      return CGFloat(self.artworkImage.layer.shadowOpacity)
    }
    set {
      self.artworkImage.layer.shadowOpacity = Float(newValue)
    }
  }

  // MARK: - Lifecycle

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)

    self.setup()
  }

  override init(frame: CGRect) {
    super.init(frame: frame)

    self.setup()
  }

  func setupGradients(with size: CGSize) {
    var size = size
    /// Adjust size on the ipad
    if UIDevice.current.userInterfaceIdiom != .phone {
      size = CGSize(
        width: size.width,
        height: size.height * 0.504132
      )
    }

    self.leftGradientLayer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
    self.leftGradientLayer.type = .radial
    self.leftGradientLayer.startPoint = CGPoint(x: 0, y: 0)
    self.leftGradientLayer.endPoint = CGPoint(x: 1, y: 1)
    self.rightGradientLayer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
    self.rightGradientLayer.type = .radial
    self.rightGradientLayer.startPoint = CGPoint(x: 1, y: 0)
    self.rightGradientLayer.endPoint = CGPoint(x: 0, y: 1)

    self.leftGradientLayer.removeFromSuperlayer()
    self.rightGradientLayer.removeFromSuperlayer()

    self.backgroundGradientColorView.layer.insertSublayer(self.leftGradientLayer, at: 0)
    self.backgroundGradientColorView.layer.insertSublayer(self.rightGradientLayer, at: 0)
  }

  private func setup() {
    self.backgroundColor = .clear

    // Load & setup xib
    Bundle.main.loadNibNamed("ArtworkControl", owner: self, options: nil)

    self.addSubview(self.contentView)

    self.contentView.translatesAutoresizingMaskIntoConstraints = false

    // View & Subviews
    self.layer.shadowColor = UIColor.black.cgColor
    self.layer.shadowOffset = CGSize(width: 0.0, height: 4.0)
    self.layer.shadowOpacity = 0.15
    self.layer.shadowRadius = 12.0

    self.titleLabel.isAccessibilityElement = false
    self.authorLabel.isAccessibilityElement = false

    self.artworkImage.clipsToBounds = false
    // artwork now has the main info regarding the title and author
    self.artworkImage.contentMode = .scaleAspectFit
    self.artworkImage.layer.cornerRadius = 9.5
    self.artworkImage.layer.masksToBounds = true
    self.artworkImage.layer.borderColor = UIColor.clear.cgColor

    self.artworkOverlay.clipsToBounds = false
    self.artworkOverlay.contentMode = .scaleAspectFit
    self.artworkOverlay.layer.cornerRadius = 9.5
    self.artworkOverlay.layer.masksToBounds = true

    self.backgroundGradientColorView.clipsToBounds = false
    self.backgroundGradientColorView.layer.cornerRadius = 9.5
    self.backgroundGradientColorView.layer.masksToBounds = true
    self.backgroundGradientColorView.layer.borderColor = UIColor.clear.cgColor
    self.setupAirplayView()

    let size = UIDevice.current.userInterfaceIdiom == .phone
    ? bounds.size
    : UIScreen.main.bounds.size

    self.setupGradients(with: size)
    self.setupConstraints()
    self.setUpTheming()
  }

  func setupConstraints() {
    let safeLayoutGuide = safeAreaLayoutGuide

    NSLayoutConstraint.activate([
      contentView.topAnchor.constraint(equalTo: safeLayoutGuide.topAnchor),
      contentView.leadingAnchor.constraint(equalTo: safeLayoutGuide.leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: safeLayoutGuide.trailingAnchor),
      contentView.bottomAnchor.constraint(equalTo: safeLayoutGuide.bottomAnchor),
    ])
  }

  private func setupAirplayView() {
    let airplayRoutePickerView = AVRoutePickerView()

    self.airplayView.addSubview(airplayRoutePickerView)
    airplayRoutePickerView.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      airplayRoutePickerView.topAnchor.constraint(equalTo: self.airplayView.topAnchor),
      airplayRoutePickerView.bottomAnchor.constraint(equalTo: self.airplayView.bottomAnchor),
      airplayRoutePickerView.leadingAnchor.constraint(equalTo: self.airplayView.leadingAnchor),
      airplayRoutePickerView.trailingAnchor.constraint(equalTo: self.airplayView.trailingAnchor, constant: -5)
    ])

    // Adjust icon size
    airplayRoutePickerView.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
    airplayRoutePickerView.tintColor = .white
    airplayRoutePickerView.activeTintColor = .white

    // Add drop shadow
    airplayRoutePickerView.layer.shadowColor = UIColor.black.cgColor
    airplayRoutePickerView.layer.shadowOpacity = 1
    airplayRoutePickerView.layer.shadowRadius = 3.0
    airplayRoutePickerView.layer.shadowOffset = CGSize(width: 0.0, height: 2.0)

    self.airplayView.isAccessibilityElement = true
    self.airplayView.accessibilityLabel = "audio_source_title".localized
  }

  public func setupInfo(
    with title: String,
    author: String
  ) {
    self.titleLabel.text = title
    self.authorLabel.text = author
    self.artworkOverlay.isAccessibilityElement = true
    self.artworkOverlay.accessibilityLabel = VoiceOverService.playerMetaText(
      title: title,
      author: author
    )
  }

  public func setupArtworkImage(relativePath: String) {
    self.artworkImage.kf.setImage(
      with: ArtworkService.getArtworkProvider(for: relativePath),
      options: [.targetCache(ArtworkService.cache)],
      completionHandler: { result in
        switch result {
        case .success(let value):
          self.artworkImage.image = value.image
          self.artworkImage.isHidden = false
        case .failure:
          self.artworkImage.image = nil
          self.artworkImage.isHidden = true
        }
      }
    )
  }
}

extension ArtworkControl: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.titleLabel.textColor = .white
    self.authorLabel.textColor = theme.linkColor.mix(with: .white)
    self.backgroundGradientColorView.backgroundColor = theme.linkColor

    self.leftGradientLayer.colors = ArtworkService.getLeftGradiants(for: theme.linkColor)
    self.rightGradientLayer.colors = ArtworkService.getRightGradiants(for: theme.linkColor)
    self.leftGradientLayer.removeFromSuperlayer()
    self.rightGradientLayer.removeFromSuperlayer()

    self.backgroundGradientColorView.layer.insertSublayer(self.leftGradientLayer, at: 0)
    self.backgroundGradientColorView.layer.insertSublayer(self.rightGradientLayer, at: 0)
  }
}
