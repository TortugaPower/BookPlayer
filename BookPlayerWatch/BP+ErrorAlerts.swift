//
//  BP+ErrorAlerts.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 11/11/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation
import SwiftUI

extension View {
  func errorAlert(
    error: Binding<Error?>,
    buttonTitle: String = "OK"
  )
    -> some View
  {
    let localizedAlertError = LocalizedAlertError(error: error.wrappedValue)
    return alert(
      isPresented: .constant(localizedAlertError != nil),
      error: localizedAlertError
    ) { _ in
      Button(buttonTitle) {
        error.wrappedValue = nil
      }
    } message: { error in
      Text(error.recoverySuggestion ?? "")
    }
  }
}

struct LocalizedAlertError: LocalizedError {
  var errorDescription: String?
  var recoverySuggestion: String?

  init?(error: Error?) {
    if let localizedError = error as? LocalizedError {
      self.errorDescription = localizedError.errorDescription
      self.recoverySuggestion = localizedError.recoverySuggestion
    } else if let error {
      self.errorDescription = error.localizedDescription
      self.recoverySuggestion = nil
    } else {
      return nil
    }
  }
}
