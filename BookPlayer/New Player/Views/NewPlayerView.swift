//
//  NewPlayerView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct SleepTimerCustomView: View {
    @Binding var isPresented: Bool
    
    // Data model for the list
    let options = [
        "Off", "In 5 minutes", "In 10 minutes", "In 15 minutes",
        "In 30 minutes", "In 45 minutes", "In 1 hour",
        "End of current chapter", "Custom"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Pause playback")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.gray)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .secondarySystemBackground))
            
            Divider()
            
            // Options List
            ForEach(options, id: \.self) { option in
                Button(action: {
                    print("Selected: \(option)")
                    isPresented = false
                }) {
                    Text(option)
                        .font(.body)
                        .foregroundColor(.blue) // Matches the blue tint in your image
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                
                // Add divider for all except the last item
                if option != options.last {
                    Divider()
                        .background(Color.gray.opacity(0.3))
                }
            }
        }
        .frame(width: 300) // Adjust width as needed
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(14)
        .shadow(radius: 10)
    }
}

struct NewPlayerView: View {
  @Environment(\.colorScheme) private var scheme
  @Environment(\.dismiss) private var dismiss
  
  @StateObject private var viewModel: NewPlayerViewModel
  @StateObject private var theme = ThemeViewModel()
  @State private var dragOffset: CGSize = .zero
  
  init(initModel: @escaping () -> NewPlayerViewModel) {
    self._viewModel = .init(wrappedValue: initModel())
  }
  
  var body: some View {
    @Bindable var data = viewModel.progressData
    
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
        .background(Color.pink)
      
      ArtworkView(imagePath: viewModel.relativePath)
        .background(Color.red)
      
      VStack(spacing: 12) {
        NavigationRowView(playerTitle: viewModel.progressData.chapterTitle)
          .background(Color.cyan)
        
        ListeningProgressView(
          progress: $data.sliderValue,
          remainigTime: viewModel.progressData.formattedMaxTime ?? "00:00",
          currentTime: viewModel.progressData.formattedCurrentTime,
          progressLabel: viewModel.progressData.progress ?? "") { progress in
            viewModel.handleSliderUpEvent(with: Float(progress))
          }
          .background(Color.blue)
        
        PlayControlsRowView(isPlaying: viewModel.isPlaying)
          .padding(.top, 24)
          .background(Color.indigo)
      }
      MediaActionsRowView(action: { media in
        viewModel.handleSleepTimerTap(media: media)
      })
        .background(Color.orange)
        .padding(.top, 16)
        .background(Color.yellow)
        .bpDialog($viewModel.currentAlert)
        .bpAlert($viewModel.currentAlert)
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
    .onAppear {
      viewModel.recalculateProgress()
    }
    .environmentObject(theme)
    .onChange(of: scheme) {
      ThemeManager.shared.checkSystemMode()
    }
    .sheet(isPresented: $viewModel.isShowingControls) {
      PlayerControlsView{
        PlayerControlsViewModel(playerManager: viewModel.playerManager)
      }
        .presentationDetents([.medium])
    }
    .sheet(isPresented: $viewModel.isShowingChapters) {
      ChaptersView{
        ChaptersViewModel(playerManager: viewModel.playerManager)
      }
    }
    .sheet(isPresented: $viewModel.isShowingBookmark) {
      BookmarksView{
        BookmarksViewModel(
          playerManager: viewModel.playerManager,
          libraryService: viewModel.libraryService,
          syncService: viewModel.syncService
        )
      }
    }
    .sheet(isPresented: $viewModel.isShowingButtonFree) {
      ButtonFreeView{
        ButtonFreeViewModel(
          playerManager: viewModel.playerManager,
          libraryService: viewModel.libraryService,
          syncService: viewModel.syncService
        )
      }
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
