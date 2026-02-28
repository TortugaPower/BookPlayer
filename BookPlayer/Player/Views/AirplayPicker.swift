//
//  AirplayPicker.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 10/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import AVKit

struct AirplayPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        
        // Match your tint styling
        picker.tintColor = .white
        picker.activeTintColor = .white
        
        // Apply the 1.4x scale transform
        picker.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
        
        // Remove background if any to ensure shadow looks right
        picker.backgroundColor = .clear
        
        return picker
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        // No dynamic updates needed for this static setup
    }
}
