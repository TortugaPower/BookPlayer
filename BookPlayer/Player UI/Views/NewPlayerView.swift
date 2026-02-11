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

  @State private var viewModel: NewPlayerViewModel
  @StateObject private var theme = ThemeViewModel()
  
  @State private var dragOffset: CGSize = .zero
  
  init(initModel: @escaping () -> NewPlayerViewModel) {
    self._viewModel = .init(wrappedValue: initModel())
  }
  
  var body: some View {
    VStack(spacing: 48) {
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
      ArtworkView()
      Spacer()
      NavigationRowView(playerTitle: viewModel.progressData.chapterTitle)
      ListeningProgressView()
      PlayControlsRowView()
      Spacer()
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

/*
#Preview {
  NewPlayerView(viewModel: NewPl)
}
*/
