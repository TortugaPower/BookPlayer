//
//  BPInputAlert.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 12/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//
import SwiftUI

struct BPInputAlertContent: View {
  let title: String
  let onCancel: () -> Void
  let onOK: (String) -> Void
  
  @State private var text = ""
  @FocusState private var focused: Bool
  
  var body: some View {
    VStack(spacing: 0) {
      
      // Title + field
      VStack(spacing: 12) {
        Text(title)
          .font(.headline)
          .multilineTextAlignment(.center)
        
        TextField("Enter text", text: $text)
          .textFieldStyle(.roundedBorder)
          .focused($focused)
      }
      .padding(20)
      
      Divider()
      
      // Buttons row
      HStack(spacing: 0) {
        
        Button("Cancel") {
          onCancel()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        
        Divider()
        
        Button("OK") {
          onOK(text)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .fontWeight(.semibold)
      }
      .fixedSize(horizontal: false, vertical: true)
      
    }
    .frame(width: 270)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .shadow(radius: 20)
    .onAppear { focused = true }
  }
}

struct BPInputAlertModifier: ViewModifier {
  @Binding var isPresented: Bool
  
  let title: String
  let onOK: (String) -> Void
  
  func body(content: Content) -> some View {
    content.overlay {
      if isPresented {
        ZStack {
          Color.black.opacity(0.35)
            .ignoresSafeArea()
            .onTapGesture {
              dismiss()
            }
          
          BPInputAlertContent(
            title: title,
            onCancel: dismiss,
            onOK: { text in
              dismiss()
              onOK(text)
            }
          )
          .transition(.scale.combined(with: .opacity))
        }
        .ignoresSafeArea(.keyboard)
        .animation(.easeOut(duration: 0.2), value: isPresented)
      }
    }
  }
  
  private func dismiss() {
    isPresented = false
  }
}

extension View {
  func bpInputAlert(
    isPresented: Binding<Bool>,
    title: String,
    onOK: @escaping (String) -> Void
  ) -> some View {
    modifier(
      BPInputAlertModifier(
        isPresented: isPresented,
        title: title,
        onOK: onOK
      )
    )
  }
}
