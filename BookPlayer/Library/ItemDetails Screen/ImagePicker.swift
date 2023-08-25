//
//  ImagePicker.swift
//  BookPlayer
//
//  Created by gianni.carlo on 19/12/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import PhotosUI
import SwiftUI

/// Taken from https://www.hackingwithswift.com/books/ios-swiftui/importing-an-image-into-swiftui-using-phpickerviewcontroller
/// for iOS 14, 15 support
struct ImagePicker: UIViewControllerRepresentable {
  @Binding var image: UIImage?
  
  func makeUIViewController(context: Context) -> PHPickerViewController {
    var config = PHPickerConfiguration()
    config.filter = .images
    let picker = PHPickerViewController(configuration: config)
    picker.delegate = context.coordinator
    return picker
  }
  
  func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
  
  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }
  
  class Coordinator: NSObject, PHPickerViewControllerDelegate {
    let parent: ImagePicker
    
    init(_ parent: ImagePicker) {
      self.parent = parent
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
      picker.dismiss(animated: true)
      
      guard
        let provider = results.first?.itemProvider,
        provider.canLoadObject(ofClass: UIImage.self)
      else { return }
      
      provider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
        DispatchQueue.main.async {
          self?.parent.image = image as? UIImage
        }
      }
    }
  }
}
