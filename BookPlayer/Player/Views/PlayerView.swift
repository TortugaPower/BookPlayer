//
//  PlayerView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import BookPlayerKit

struct PlayerView: View {
  @Environment(\.colorScheme) private var scheme
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  
  @StateObject private var viewModel: PlayerViewModel
  @StateObject private var theme = ThemeViewModel()
  @State private var noteText: String = ""
  @State private var dragOffset: CGSize = .zero
  @State private var dragThresholdReached = false
  let dismissThreshold: CGFloat = 44.0 * UIScreen.main.nativeScale
  
  init(initModel: @escaping () -> PlayerViewModel) {
    self._viewModel = .init(wrappedValue: initModel())
  }
  
  var body: some View {    
    VStack {
      DismissableRegionView()
        .simultaneousGesture(
          DragGesture(minimumDistance: 15)
            .onChanged { gesture in
              handleDragChanged(gesture)
            }
            .onEnded { gesture in
              handleDragEnded(gesture)
            }
        )
      
      VStack {
        ArtworkView(
          title: viewModel.title,
          author: viewModel.author,
          imagePath: viewModel.relativePath
        )
        .simultaneousGesture(
          DragGesture(minimumDistance: 15)
            .onChanged { gesture in
              handleDragChanged(gesture)
            }
            .onEnded { gesture in
              handleDragEnded(gesture)
            }
        )
        
        Spacer()
      }
      .frame(maxWidth: .infinity)

      VStack(spacing: 4) {
        NavigationRowView(
          playerTitle: viewModel.progressData.chapterTitle,
          hasNextChapter: viewModel.hasNextChapter,
          hasPreviousChapter: viewModel.hasPreviousChapter,
          onNextTap: viewModel.handleNextTap,
          onTitleToggle: viewModel.processToggleProgressState,
          onPreviousTap: viewModel.handlePreviousTap
        )

        ListeningProgressView(
          progress: $viewModel.progressData.sliderValue,
          remainingTime: viewModel.progressData.formattedMaxTime ?? "00:00",
          remainingTimeAccessLabel: viewModel.remainingTimeAccessLabel,
          currentTime: viewModel.progressData.formattedCurrentTime,
          currentTimeAccessLabel: viewModel.currentTimeAccessLabel,
          progressLabel: viewModel.progressData.progress ?? "",
          onSliderDragChanged: { value in
            viewModel.handleSliderDragChanged(value: value)
          },
          onSliderChange: { progress in
            viewModel.handleSliderUpEvent(with: Float(progress))
          },
          onProgressToggle: {
            viewModel.processToggleProgressState()
          },
          onRemainingToggle: {
            viewModel.processToggleMaxTime()
          }
        )

        Spacer()

        PlayControlsRowView(isPlaying: viewModel.isPlaying)

        Spacer()
      }
      .contentShape(Rectangle())
      .simultaneousGesture(
        DragGesture(minimumDistance: 15)
          .onChanged(handleDragChanged)
          .onEnded(handleDragEnded)
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(.horizontal, 8)
    .safeAreaPadding([.top, .horizontal])
    .safeAreaInset(edge: .bottom) {
      MediaActionRow(
        speedText: viewModel.formattedSpeed(),
        sleepText: viewModel.sleepText,
        sleepAccessibilityLabel: viewModel.sleepAccessibilityLabel,
        currentAlert: $viewModel.currentAlert,
        currentAlertOrigin: viewModel.currentAlertOrigin,
        onActionTapped: { viewModel.handleButtonTap(media: $0) }
      )
      .frame(height: 48)
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 8)
    }
    .background(
      RoundedRectangle(cornerRadius: 24)
        .fill(theme.systemBackgroundColor)
        .ignoresSafeArea()
    )
    .offset(y: dragOffset.height)
    .animation(reduceMotion ? .none : .interactiveSpring(), value: dragOffset)
    .onAppear {
      viewModel.bindBookObservers()
      viewModel.handleAutolockStatus(forceDisable: false)
      viewModel.recalculateProgress()
    }
    .onDisappear {
      viewModel.handleAutolockStatus(forceDisable: true)
    }
    .accessibilityAction(.escape) {
      dismiss()
    }
    .environmentObject(theme)
    .onChange(of: scheme) { 
      ThemeManager.shared.checkSystemMode()
    }
    .buttonStyle(.plain)
    .bpAlert($viewModel.currentAlert)
    .alert(
        "bookmark_note_action_title",
        isPresented: Binding(
          get: { viewModel.lastBookmark != nil },
          set: { if !$0 { viewModel.lastBookmark = nil; noteText = "" } }
        ),
        presenting: viewModel.lastBookmark
    ) { _ in
      TextField("note_title", text: $noteText)
      Button("cancel_button", role: .cancel) {}
      Button("ok_button") {
        viewModel.saveNote(note: noteText)
      }
    }
    .sheet(item: $viewModel.sheetStyle) { style in
      switch style {
      case .controls:
        PlayerControlsView{
          PlayerControlsViewModel(playerManager: viewModel.playerManager)
        }
        .presentationDetents([.medium])
        .environmentObject(theme)
      case .chapters:
        ChaptersView{
          ChaptersViewModel(playerManager: viewModel.playerManager)
        }
        .environmentObject(theme)
      case .bookmark:
        BookmarksView{
          BookmarksViewModel(
            playerManager: viewModel.playerManager,
            libraryService: viewModel.libraryService,
            syncService: viewModel.syncService
          )
        }
        .environmentObject(theme)
      case .sleep:
        DurationPickerSheet(
          initialDuration: UserDefaults.standard.double(forKey: Constants.UserDefaults.customSleepTimerDuration)
        ) { seconds in
          UserDefaults.standard.set(seconds, forKey: Constants.UserDefaults.customSleepTimerDuration)
          SleepTimer.shared.setTimer(.countdown(seconds))
        }
        .environmentObject(theme)
      }
    }
    .fullScreenCover(isPresented: $viewModel.showButtonFreeScreen) {
      ButtonFreeView{
        ButtonFreeViewModel(
          playerManager: viewModel.playerManager,
          libraryService: viewModel.libraryService,
          syncService: viewModel.syncService
        )
      }
      .environmentObject(theme)
    }
  }
  
  private func handleDragChanged(_ gesture: DragGesture.Value) {
    if gesture.translation.height > 0 {
      dragOffset = gesture.translation
    }

    if gesture.translation.height > dismissThreshold, !dragThresholdReached {
      dragThresholdReached = true
      UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
  }

  private func handleDragEnded(_ gesture: DragGesture.Value) {
    dragThresholdReached = false

    if gesture.translation.height > dismissThreshold {
      dismiss()
    } else {
      dragOffset = .zero
    }
  }
}
