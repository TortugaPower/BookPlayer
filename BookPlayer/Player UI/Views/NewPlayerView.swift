//
//  NewPlayerView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct NewPlayerView: View {
  @Environment(\.colorScheme) private var scheme
  @Environment(\.dismiss) private var dismiss
  
  @StateObject private var theme = ThemeViewModel()
  
  @State private var dragOffset: CGSize = .zero
  
  var body: some View {
    VStack(spacing: 48) {
      
      // 1️⃣ Wide Touchable Area (Drag to dismiss)
      DismissableRegionView()
        .gesture(
          DragGesture()
            .onChanged { gesture in
              handleDragChanged(gesture)
            }
            .onEnded { gesture in
              handleDragEnded(gesture)
            }
        )
      
      // 2️⃣ Image with floating icons
      ArtworkView()
      Spacer()
      // 3️⃣ Left actions - Text - Right actions
      NavigationRowView()
      
      // 4️⃣ Progress + labels
      ListeningProgressView()
      
      // 5️⃣ Action icons row
      PlayControlsRowView()
      Spacer()
      // 6️⃣ Bubble icon buttons
      MediaActionsRowView()
    }
    .padding(.horizontal, 20)
    .cornerRadius(16)
    .safeAreaPadding()
    .background(
      RoundedRectangle(cornerRadius: 24)
        .fill(Color(theme.systemGroupedBackgroundColor))
        .ignoresSafeArea()
    )
    .offset(y: dragOffset.height)
    .animation(.interactiveSpring(), value: dragOffset)
    .environmentObject(theme)
    .onChange(of: scheme) {
      ThemeManager.shared.checkSystemMode()
    }
  }
  
  private func handleDragChanged(_ gesture: DragGesture.Value) {
    if gesture.translation.height > 0 {
      dragOffset = gesture.translation
    }
  }
  
  private func handleDragEnded(_ gesture: DragGesture.Value) {
    let threshold: CGFloat = 150
    
    if gesture.translation.height > threshold {
      dismiss()
    } else {
      dragOffset = .zero
    }
  }
}

#Preview {
  NewPlayerView()
}
