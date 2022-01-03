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
    public private(set) var currentSpeed = CurrentValueSubject<Float, Never>(1.0)
    @IBOutlet var bar: ProgressSlider!
    @IBOutlet var label: UILabel!
    
    var minimumValue = 0.1
    var maximumvalue = 5.0
    var step = 0.05
    
    private var playerManager: PlayerManagerProtocol!
    private var relativePath: String!
    private var libraryService: LibraryServiceProtocol!
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public init(title: String?, playerManager: PlayerManagerProtocol, relativePath: String, libraryService: LibraryServiceProtocol) {
        super.init(nibName: nil, bundle: nil)
        self.playerManager = playerManager
        self.relativePath = relativePath
        self.libraryService = libraryService
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let speed: Float
        
        if UserDefaults.standard.bool(forKey: Constants.UserDefaults.globalSpeedEnabled.rawValue) {
          speed = UserDefaults.standard.float(forKey: "global_speed")
        } else if let relativePath = relativePath {
            speed = self.libraryService.getItemSpeed(at: relativePath)
        } else {
          speed = self.currentSpeed.value
        }
        
        self.currentSpeed.value = speed > 0 ? speed : 1.0
        self.bar.minimumValue = Float(self.minimumValue)
        self.bar.maximumValue = Float(self.maximumvalue)
        self.bar.value = speed
        self.label.text = String(describing: speed)
    }
    
    private func changeUi(value: Float) {
        let val_str = String(format: "%.2f", Float(value))
        var val = Float(val_str) ?? 1.0
        if val > Float(self.maximumvalue) {
            val = Float(self.maximumvalue)
        }
        if val > Float(self.maximumvalue) {
            val = Float(self.maximumvalue)
        }
        
        self.bar.value = val
        self.currentSpeed.value = val
        self.label.text = String(describing: val)
    }
    
    @IBAction func incSpeed(_ sender: Any) {
        self.changeUi(value: self.currentSpeed.value + Float(self.step))
        self.playerManager.setSpeed(self.currentSpeed.value, relativePath: relativePath)
    }
    
    @IBAction func decSpeed(_ sender: Any) {
        self.changeUi(value: self.currentSpeed.value - Float(self.step))
        self.playerManager.setSpeed(self.currentSpeed.value, relativePath: relativePath)
    }
    
    @IBAction func changeSpeed(_ sender: Any) {
        self.changeUi(value: Float(String(format: "%.1f", self.bar.value))!)
        self.playerManager.setSpeed(self.currentSpeed.value, relativePath: relativePath)
    }
    
    @IBAction func onSave(_ sender: Any) {
        self.libraryService.updateBookSpeed(at: relativePath, speed: self.currentSpeed.value)
        self.playerManager.setSpeed(self.currentSpeed.value, relativePath: relativePath)
        
        // set global speed
        if UserDefaults.standard.bool(forKey: Constants.UserDefaults.globalSpeedEnabled.rawValue) {
            UserDefaults.standard.set(self.currentSpeed.value, forKey: "global_speed")
        }
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func onClose(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func onDefault(_ sender: Any) {
        self.libraryService.updateBookSpeed(at: relativePath, speed: 1.0)
        self.playerManager.setSpeed(1.0, relativePath: relativePath)
        
        // set global speed
        if UserDefaults.standard.bool(forKey: Constants.UserDefaults.globalSpeedEnabled.rawValue) {
            UserDefaults.standard.set(1.0, forKey: "global_speed")
        }
        
        dismiss(animated: true, completion: nil)
    }
}
