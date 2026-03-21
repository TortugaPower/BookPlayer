//
//  ExternalImportViewModel.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 17/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//
import Foundation
import SwiftUI
import BookPlayerKit

protocol ExternalViewModelProtocol: ObservableObject {
  var resources: [SimpleExternalResource] { get set }
  func removeResource(withId id: String)
  func handleImportResources() async
}

class ExternalImportViewModel: ExternalViewModelProtocol {
  let importManager: ImportManager
  
  var resources: [SimpleExternalResource] {
    get {
      print(importManager.externalFiles.description)
      return importManager.externalFiles
    }
    set {
      importManager.externalFiles = newValue
    }
  }
  
  init(
    importManager: ImportManager
  ) {
    self.importManager = importManager
  }
  
  func removeResource(withId id: String) {
    importManager.externalFiles.removeAll { $0.providerId == id }
  }
  
  func handleImportResources() async {
    await importManager.processExternalFiles()
  }
}
