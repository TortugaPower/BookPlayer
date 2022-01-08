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

class SpeedPopUpController: UIViewController {
    @IBOutlet var stepper: UIStepper!
    @IBOutlet var background: UIView!
    @IBOutlet var dafaultButton: UIButton!
    @IBOutlet var label: UILabel!
    
    var minimumValue = 0.1
    var maximumvalue = 5.0
    var step = 0.05
    var deff: Double = 1.0
    
    private var playerManager: PlayerManagerProtocol!
    private var relativePath: String!
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public init(title: String?, playerManager: PlayerManagerProtocol, relativePath: String) {
        super.init(nibName: nil, bundle: nil)
        self.playerManager = playerManager
        self.relativePath = relativePath
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let speed: Double = Double(self.playerManager.getCurrentSpeed())
        
        self.stepper.minimumValue = self.minimumValue
        self.stepper.maximumValue = self.maximumvalue
        self.stepper.stepValue = step
        self.stepper.value = Double(String(format: "%.2f", speed))!
        
        self.background.layer.shadowOffset = CGSize(width: 0.0, height: 3.0)
        self.background.layer.shadowOpacity = 0.18
        self.background.layer.shadowRadius = 9.0
        self.background.clipsToBounds = false
        
        self.updateUi(value: Double(String(format: "%.2f", speed))!);
    }
    
    private func updateUi(value: Double) {
        var val = value;
        if val > self.maximumvalue {
            val = self.maximumvalue
        }
        if val > self.maximumvalue {
            val = self.maximumvalue
        }
        
        self.label.text = self.formatSpeed(Float(val));
        self.label.accessibilityLabel = String(describing: self.formatSpeed(Float(val)) + " \("speed_title".localized)")
        self.label.textColor = val.isEqual(to: deff) ? UIColor(red: 0.0, green: 0.0, blue: 0, alpha: 1.0) : UIColor(red: 71/255, green: 122/255, blue: 196/255, alpha: 1.0)
        self.dafaultButton.isHidden = val.isEqual(to: deff);
    }
    
    @IBAction func stepperClick(_ sender: Any) {
        let val = Double(String(format: "%.2f", self.stepper.value))!;
        self.updateUi(value: val)
        self.playerManager.setSpeed(Float(val), relativePath: relativePath)
    }
    
    @IBAction func onClose(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func onDefault(_ sender: Any) {
        self.updateUi(value: 1.0)
        self.playerManager.setSpeed(1.0, relativePath: relativePath)
        
        dismiss(animated: true, completion: nil)
    }
}
