//
//  SpeedPopUpController.swift
//  BookPlayer
//
//  Created by Pavel Kyzmin on 03.01.2022.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import UIKit
import BookPlayerKit
import Combine
import Foundation
import AVFoundation
import AVKit
import BookPlayerKit
import Combine
import MediaPlayer
import StoreKit
import Themeable

class SpeedViewController: BaseViewController<SpeedCoordinator, SpeedViewModel>, TelemetryProtocol, Storyboarded {
    private var disposeBag = Set<AnyCancellable>()
    
    @IBOutlet var stepper: UIStepper!
    @IBOutlet var dafaultButton: UIButton!
    @IBOutlet var label: UILabel!
    @IBOutlet var background: UIView!

    let minimumValue = 0.1
    let maximumvalue = 5.0
    let step = 0.05
    let deff: Double = 1.0
  
    override func viewDidLoad() {
        super.viewDidLoad()
        let speed: Double = Double(self.viewModel.getCurrentSpeed())
        
        self.stepper.minimumValue = self.minimumValue
        self.stepper.maximumValue = self.maximumvalue
        self.stepper.stepValue = step
        self.stepper.value = Double(String(format: "%.2f", speed))!
        
        self.background.layer.shadowOffset = CGSize(width: 0.0, height: 3.0)
        self.background.layer.shadowOpacity = 0.18
        self.background.layer.shadowRadius = 9.0
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
              var val = Double(speed);
              if val > self.maximumvalue {
                  val = self.maximumvalue
              }
              if val > self.maximumvalue {
                  val = self.maximumvalue
              }
            
              self.label.text = formattedSpeed
              self.label.accessibilityLabel = String(describing: formattedSpeed + " \("speed_title".localized)")
              self.label.textColor = val.isEqual(to: self.deff) ? UIColor(red: 0.0, green: 0.0, blue: 0, alpha: 1.0) : UIColor(red: 71/255, green: 122/255, blue: 196/255, alpha: 1.0)
              self.dafaultButton.isHidden = val.isEqual(to: self.deff);
            }
            .store(in: &disposeBag)
    }

    @IBAction func onClose(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func onDefault(_ sender: Any) {
        self.viewModel.setSpeed(val: 1.0)
        dismiss(animated: true, completion: nil)
    }
}
