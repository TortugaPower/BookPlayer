//
//  NewPlayerView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import BookPlayerKit

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
    
    VStack {
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
      
      VStack {
        ArtworkView(imagePath: viewModel.relativePath)
        Spacer()
      }
      .frame(maxWidth: .infinity)

      VStack(spacing: 4) {
        NavigationRowView(
          playerTitle: viewModel.progressData.chapterTitle,
          hasNextChapter: viewModel.hasNextChapter,
          hasPreviousChapter: viewModel.hasPreviousChapter
        )
        
        ListeningProgressView(
          progress: $data.sliderValue,
          remainingTime: viewModel.progressData.formattedMaxTime ?? "00:00",
          remainingTimeAccessLabel: viewModel.remainingTimeAccessLabel,
          currentTime: viewModel.progressData.formattedCurrentTime,
          currentTimeAccessLabel: viewModel.currentTimeAccessLabel,
          progressLabel: viewModel.progressData.progress ?? "") { progress in
            viewModel.handleSliderUpEvent(with: Float(progress))
          } onProgresToggle: {
            self.viewModel.processToggleProgressState()
          } onRemainingToggle: {
            self.viewModel.processToggleMaxTime()
          }
        
        Spacer()
        
        PlayControlsRowView(isPlaying: viewModel.isPlaying)
        
        Spacer()
        
        HStack {
          ForEach(MediaAction.allCases) { ma in
            BubbleButton(
              iconName: ma == .speed ? nil : ma.iconName,
              labelText: ma == .speed
                ? "\(viewModel.formattedSpeed())"
                : ma == .timer && viewModel.sleepText != nil
                  ? viewModel.sleepText
                  : nil,
              action: {
                viewModel.handleSleepTimerTap(media: ma)
              }
            )
              .accessibilityLabel(
                ma != .speed
                  ? ma.accessibilityLabel
                  : String(describing: viewModel.formattedSpeed() + " \("speed_title".localized)")
              )
              .bpDialog(
                $viewModel.currentAlert,
                isOriginView: viewModel.currentAlertOrigin == ma
              )
            
            if ma != MediaAction.allCases.last {
                Spacer()
            }
          }
        }
        .frame(maxWidth: .infinity)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(.horizontal, 24)
    .safeAreaPadding()
    .background(
      RoundedRectangle(cornerRadius: 24)
        .fill(theme.systemBackgroundColor)
        .ignoresSafeArea()
    )
    .offset(y: dragOffset.height)
    .animation(.interactiveSpring(), value: dragOffset)
    .onAppear {
      viewModel.recalculateProgress()
    }
    .accessibilityAction(.escape) {
      dismiss()
    }
    .environmentObject(theme)
    .onChange(of: scheme) {
      ThemeManager.shared.checkSystemMode()
    }
    .bpAlert($viewModel.currentAlert)
    .bpInputAlert(
        isPresented: $viewModel.isShowingNote,
        title: "bookmark_note_action_title".localized
    ) { text in
      self.viewModel.saveNote(note: text)
    }
    .sheet(isPresented: $viewModel.playerSheetData.display) {
      switch viewModel.playerSheetData.style {
        case .controls:
          PlayerControlsView{
            PlayerControlsViewModel(playerManager: viewModel.playerManager)
          }
            .presentationDetents([.medium])
        case .chapters:
          ChaptersView{
            ChaptersViewModel(playerManager: viewModel.playerManager)
          }
        case .bookmark:
          BookmarksView{
            BookmarksViewModel(
              playerManager: viewModel.playerManager,
              libraryService: viewModel.libraryService,
              syncService: viewModel.syncService
            )
          }
        case .buttonFree:
          ButtonFreeView{
            ButtonFreeViewModel(
              playerManager: viewModel.playerManager,
              libraryService: viewModel.libraryService,
              syncService: viewModel.syncService
            )
          }
        case .sleep:
          DurationPickerSheet(
            initialDuration: UserDefaults.standard.double(forKey: Constants.UserDefaults.customSleepTimerDuration)
          ) { seconds in
            UserDefaults.standard.set(seconds, forKey: Constants.UserDefaults.customSleepTimerDuration)
            SleepTimer.shared.setTimer(.countdown(seconds))
          }
        case .none:
          Text("N/A")
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
