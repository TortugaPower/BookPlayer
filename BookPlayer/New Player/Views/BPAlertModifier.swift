//
//  BPAlertModifier.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 11/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct BPAlertModifier: ViewModifier {
  @Binding var alertContent: BPAlertContent?
  
  func body(content: Content) -> some View {
    content
      .alert(
        alertContent?.title ?? "",
        isPresented: Binding(
          get: { alertContent?.style == .alert },
          set: { if !$0 { alertContent = nil } }
        ),
        presenting: alertContent
      ) { alert in
        
        ForEach(alert.actionItems, id: \.title) { item in
          Button(item.title, role: role(for: item.style)) {
            item.handler()
          }
          .disabled(!item.isEnabled)
        }
        
      } message: { alert in
        if let message = alert.message {
          Text(message)
        }
      }
  }
  
  private func role(for style: UIAlertAction.Style) -> ButtonRole? {
    switch style {
    case .destructive: return .destructive
    case .cancel: return .cancel
    default: return nil
    }
  }
}

extension View {
  func bpAlert(_ alertContent: Binding<BPAlertContent?>) -> some View {
    modifier(BPAlertModifier(alertContent: alertContent))
  }
}


/*
 #Preview {
  BPAlertModifier()
 }
*/
