//
//  Extensions.swift
//  Audiobook Player
//
//  Created by Gianni Carlo on 3/10/17.
//  Copyright © 2017 Tortuga Power. All rights reserved.
//

import UIKit

extension UIViewController {
    func showAlert(_ title: String?, message: String?, style: UIAlertControllerStyle) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: style)
        let okButton = UIAlertAction(title: "Ok", style: .default, handler: nil)
        
        alert.addAction(okButton)
        
        alert.popoverPresentationController?.sourceView = self.view
        alert.popoverPresentationController?.sourceRect = CGRect(x: Double(self.view.bounds.size.width / 2.0), y: Double(self.view.bounds.size.height-45), width: 1.0, height: 1.0)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    //utility function to transform seconds to format HH:MM:SS
    func formatTime(_ time:Int) -> String {
        let hours = Int(time / 3600)
        
        let remaining = Float(time - (hours * 3600))
        
        let minutes = Int(remaining / 60)
        
        let seconds = Int(remaining - Float(minutes * 60))
        
        var formattedTime = String(format:"%02d:%02d", minutes, seconds)
        if hours > 0 {
            formattedTime = String(format:"%02d:"+formattedTime, hours)
        }
        
        return formattedTime
    }
}

extension UINavigationController {
    override open var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }
}

extension Notification.Name {
    
    public struct AudiobookPlayer {
        public static let openURL = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.openurl")
        public static let requestReview = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.requestreview")
    }
}

