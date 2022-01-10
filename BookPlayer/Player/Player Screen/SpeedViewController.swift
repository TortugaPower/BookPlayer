//
//  SpeedPopUpController.swift
//  BookPlayer
//
//  Created by Pavel Kyzmin on 03.01.2022.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Combine
import Foundation
import BookPlayerKit
import Themeable

class SpeedViewController: BaseViewController<SpeedCoordinator, SpeedViewModel>, TelemetryProtocol, Storyboarded {
    private var disposeBag = Set<AnyCancellable>()

    @IBOutlet var closeButton: UIButton!
    @IBOutlet var stepper: UIStepper!
    @IBOutlet var dafaultButton: UIButton!
    @IBOutlet var label: UILabel!
    @IBOutlet var playbackLabel: UILabel!
    @IBOutlet var background: UIView!
    @IBOutlet var infoLabel: UILabel!
    
    let minimumValue = 0.1
    let maximumvalue = 5.0
    let step = 0.05
    let deff: Double = 1.0
    private var disabledTextColor: UIColor = UIColor(hex: "242320")

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.background.backgroundColor = .clear
        
        setUpTheming()
        
        setup()
    }
    
    func setup() {
        self.playbackLabel.text = "player_speed_head".localized
        self.infoLabel.text = "player_speed_title".localized

        let speed: Double = Double(self.viewModel.getCurrentSpeed())

        self.stepper.minimumValue = self.minimumValue
        self.stepper.maximumValue = self.maximumvalue
        self.stepper.stepValue = step
        self.stepper.value = Double(String(format: "%.2f", speed))!

        self.background.layer.shadowOffset = CGSize(width: 0.0, height: 3.0)
        self.background.layer.shadowOpacity = 0.18
        self.background.layer.shadowRadius = 9.0
        self.background.layer.cornerRadius = 13.0
        self.background.layer.masksToBounds = true
        self.background.clipsToBounds = false

        self.stepper.publisher(for: .valueChanged)
            .sink { control in
                guard control is UIStepper else { return }
                // This function would basically just set the speed on the SpeedManager
                self.viewModel.setSpeed(val: Float(self.stepper.value))
            }
            .store(in: &disposeBag)

        // And this one would be the listener for speed changes on the SpeedManager
        self.viewModel.currentSpeedObserver().sink { [weak self] speed in
            guard let self = self else { return }

            let formattedSpeed = self.formatSpeed(speed)
            let val = Double(speed);

            self.label.text = formattedSpeed
            self.label.accessibilityLabel = String(describing: formattedSpeed + " \("speed_title".localized)")
            self.label.textColor = val.isEqual(to: self.deff) ? self.disabledTextColor : self.viewModel.getActiveColor()
            self.dafaultButton.isHidden = val.isEqual(to: self.deff);
        }
        .store(in: &disposeBag)
    }

    @IBAction func onClose(_ sender: Any) {
        self.viewModel.dismiss()
    }

    @IBAction func onDefault(_ sender: Any) {
        self.viewModel.setSpeed(val: 1.0)
        self.viewModel.dismiss()
    }
}

extension SpeedViewController: Themeable {
    func applyTheme(_ theme: SimpleTheme) {
        self.background.layer.backgroundColor = theme.secondarySystemBackgroundColor.cgColor
        self.playbackLabel.textColor = theme.primaryColor
        self.infoLabel.textColor = theme.primaryColor
        self.disabledTextColor = UIColor(hex: theme.useDarkVariant ? theme.darkPrimaryHex : theme.lightPrimaryHex)
        self.overrideUserInterfaceStyle = theme.useDarkVariant ? UIUserInterfaceStyle.dark : UIUserInterfaceStyle.light
    }
}
