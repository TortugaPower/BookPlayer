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
  /// How far the player is dragged down to close it; the lists beside it move along
  @State private var dragOffset: CGSize = .zero

  init(initModel: @escaping () -> PlayerViewModel) {
    self._viewModel = .init(wrappedValue: initModel())
  }

  var body: some View {
    PlayerContentView(viewModel: viewModel, dragOffset: $dragOffset)
      .playerListPanel(
        playerManager: viewModel.playerManager,
        libraryService: viewModel.libraryService,
        syncService: viewModel.syncService
      )
      /// Behind the panel too when it shows
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
          PlayerListSheet { close in
            ChaptersView(onSelect: close) {
              ChaptersViewModel(
                playerManager: viewModel.playerManager,
                libraryService: viewModel.libraryService
              )
            }
          }
          .environmentObject(theme)
        case .bookmark:
          PlayerListSheet { close in
            BookmarksView(onSelect: close) {
              BookmarksViewModel(
                playerManager: viewModel.playerManager,
                libraryService: viewModel.libraryService,
                syncService: viewModel.syncService
              )
            }
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
}

/// The player itself: artwork, controls and the button row. On the open iPhone Duo it shares the
/// screen with the lists (`playerListPanel`), and the size classes it reads are its own part's:
/// above the lists, in portrait, it's as short as an iPhone in landscape and lays out the same way
private struct PlayerContentView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.displayScale) private var displayScale
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  @EnvironmentObject private var theme: ThemeViewModel

  @ObservedObject var viewModel: PlayerViewModel
  @Binding var dragOffset: CGSize
  @State private var dragThresholdReached = false
  @State private var isWide = false
  /// Side by side, the screen is about half as tall, so half the distance closes the player
  private var dismissThreshold: CGFloat { (isSideBySide ? 22.0 : 44.0) * displayScale }
  /// The artwork beside the controls in a short, wide space: iPhone in landscape, or above the
  /// lists on an open iPhone Duo in portrait. Both inputs Apple gives for a now-playing layout:
  /// with the lists hidden on a closed Duo, the size class can say compact while the player has
  /// the whole tall screen, and the shape rules that out
  private var isSideBySide: Bool { isWide && verticalSizeClass == .compact }
  /// Side by side, the artwork sits against the controls; it fills less than its half when
  /// the height is what limits it
  private var artworkAlignment: Alignment { isSideBySide ? .trailing : .center }

  var body: some View {
    /// Switching the layout keeps its views, so rotating moves them instead of rebuilding them
    let layout = isSideBySide ? AnyLayout(HStackLayout(spacing: 40)) : AnyLayout(VStackLayout())

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

      layout {
        VStack {
          ArtworkView(
            title: viewModel.title,
            author: viewModel.author,
            imagePath: viewModel.relativePath,
            alignment: artworkAlignment
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

          /// Side by side, the artwork spans the controls' full height
          Spacer(minLength: isSideBySide ? 0 : nil)
        }
        .frame(maxWidth: .infinity, alignment: artworkAlignment)
        /// VoiceOver reads by position, which side by side would mix the artwork's elements
        /// into the controls
        .accessibilityElement(children: .contain)

        VStack(spacing: 4) {
          NavigationRowView(
            playerTitle: viewModel.progressData.chapterTitle,
            hasNextChapter: viewModel.hasNextChapter,
            hasPreviousChapter: viewModel.hasPreviousChapter,
            onNextTap: viewModel.handleNextTap,
            onTitleToggle: viewModel.processToggleProgressState,
            onPreviousTap: viewModel.handlePreviousTap,
            keepsTitleHeight: !isSideBySide
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
        .accessibilityElement(children: .contain)
      }
    }
    .padding(.horizontal, 8)
    .safeAreaPadding([.top, .horizontal])
    /// Side by side, the artwork runs down to the row, so it gets some room
    .safeAreaInset(edge: .bottom, spacing: isSideBySide ? 16 : nil) {
      MediaActionRow(
        speedText: viewModel.formattedSpeed(),
        sleepText: viewModel.sleepText,
        sleepAccessibilityLabel: viewModel.sleepAccessibilityLabel,
        currentAlert: $viewModel.currentAlert,
        showsTimerPopover: $viewModel.showsCustomSleepTimer,
        currentAlertOrigin: viewModel.currentAlertOrigin,
        /// Side by side, the buttons stay together in the middle instead of spreading across
        /// the screen's full width
        buttonSpacing: isSideBySide ? 24 : nil,
        onActionTapped: { viewModel.handleButtonTap(media: $0) }
      ) {
        DurationPickerPopover(
          initialDuration: UserDefaults.standard.double(forKey: Constants.UserDefaults.customSleepTimerDuration)
        ) { seconds in
          UserDefaults.standard.set(seconds, forKey: Constants.UserDefaults.customSleepTimerDuration)
          SleepTimer.shared.setTimer(.countdown(seconds))
        }
        .environmentObject(theme)
      }
      .frame(height: 48)
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 8)
    }
    .onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height } action: { isWide = $0 }
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

/// A player list (chapters or bookmarks) as a sheet over the player: the list goes in a navigation
/// stack with a close button, and picking a row closes the sheet
private struct PlayerListSheet<Content: View>: View {
  @EnvironmentObject private var theme: ThemeViewModel
  @Environment(\.dismiss) private var dismiss
  @ViewBuilder let content: (_ close: @escaping () -> Void) -> Content

  var body: some View {
    NavigationStack {
      content { dismiss() }
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button {
              dismiss()
            } label: {
              Label("voiceover_close_button", systemImage: "xmark")
            }
            .foregroundStyle(theme.linkColor)
          }
        }
    }
  }
}
