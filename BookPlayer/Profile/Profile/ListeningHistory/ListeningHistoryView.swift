//
//  ListeningHistoryView.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ListeningHistoryView: View {
  @StateObject private var viewModel: ListeningHistoryViewModel
  @State private var loadingState = LoadingOverlayState()
  @State private var sessionToDelete: SimpleListeningSession?
  @State private var showClearAllConfirm = false
  @State private var showMissingItemAlert = false

  @EnvironmentObject private var theme: ThemeViewModel
  @Environment(\.playerLoaderService) private var playerLoaderService
  @Environment(\.playerState) private var playerState

  init(initModel: @escaping () -> ListeningHistoryViewModel) {
    self._viewModel = .init(wrappedValue: initModel())
  }

  var body: some View {
    List {
      if viewModel.isHistoryDisabled {
        ThemedSection {
          Label {
            Text("listening_history_disabled_banner")
              .bpFont(.subheadline)
              .foregroundStyle(theme.secondaryColor)
          } icon: {
            Image(systemName: "eye.slash")
              .foregroundStyle(theme.secondaryColor)
          }
          .accessibilityElement(children: .combine)
        }
      }

      if viewModel.isEmpty {
        ContentUnavailableView(
          "listening_history_empty_title",
          systemImage: "headphones",
          description: Text(
            viewModel.isHistoryDisabled
              ? "listening_history_disabled_empty_description"
              : "listening_history_empty_description"
          )
        )
        .listRowBackground(Color.clear)
      } else {
        ForEach(viewModel.sections) { section in
          ThemedSection {
            ForEach(section.sessions) { session in
              row(for: session)
            }
          } header: {
            Text(section.title)
              .foregroundStyle(theme.secondaryColor)
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .environment(\.editMode, $viewModel.editMode)
    .miniPlayerSafeAreaInset()
    .applyListStyle(with: theme, background: theme.systemBackgroundColor)
    .navigationTitle("listening_history_title")
    .navigationBarTitleDisplayMode(.inline)
    .searchable(
      text: $viewModel.searchText,
      prompt: "listening_history_search_prompt"
    )
    .onChange(of: viewModel.searchText) { _, _ in
      viewModel.reload()
    }
    .onChange(of: viewModel.dateScope) { _, _ in
      viewModel.reload()
    }
    .onAppear {
      viewModel.reload()
    }
    .onReceive(NotificationCenter.default.publisher(for: .bookPaused)) { _ in
      viewModel.reload()
    }
    .onReceive(NotificationCenter.default.publisher(for: .bookPlayed)) { _ in
      viewModel.reload()
    }
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Menu {
          ForEach(ListeningHistoryDateScope.allCases) { scope in
            Button {
              viewModel.dateScope = scope
            } label: {
              if viewModel.dateScope == scope {
                Label(LocalizedStringKey(scope.titleKey), systemImage: "checkmark")
              } else {
                Text(LocalizedStringKey(scope.titleKey))
              }
            }
          }
        } label: {
          Image(systemName: "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel(Text("listening_history_filter_title"))
      }

      ToolbarItemGroup(placement: .topBarTrailing) {
        if viewModel.editMode.isEditing {
          Button("delete_button", role: .destructive) {
            viewModel.deleteSelected()
          }
          .disabled(!viewModel.hasSelection)

          Button("done_title") {
            viewModel.editMode = .inactive
            viewModel.selectedIds.removeAll()
          }
        } else {
          Button("select_title") {
            viewModel.editMode = .active
          }
          .disabled(viewModel.isEmpty)

          Button("listening_history_clear_all_title", role: .destructive) {
            showClearAllConfirm = true
          }
          .disabled(viewModel.isEmpty)
        }
      }
    }
    .confirmationDialog(
      "listening_history_clear_all_title",
      isPresented: $showClearAllConfirm,
      titleVisibility: .visible
    ) {
      Button("listening_history_clear_all_confirm_title", role: .destructive) {
        viewModel.clearAll()
      }
      Button("cancel_button", role: .cancel) {}
    } message: {
      Text("listening_history_clear_all_message")
    }
    .alert(
      "listening_history_delete_title",
      isPresented: Binding(
        get: { sessionToDelete != nil },
        set: { if !$0 { sessionToDelete = nil } }
      )
    ) {
      Button("delete_button", role: .destructive) {
        if let sessionToDelete {
          viewModel.deleteSessions(ids: [sessionToDelete.id])
        }
        sessionToDelete = nil
      }
      Button("cancel_button", role: .cancel) {
        sessionToDelete = nil
      }
    } message: {
      if let sessionToDelete {
        Text(
          String(
            format: String(localized: String.LocalizationValue("listening_history_delete_message")),
            sessionToDelete.itemTitle
          )
        )
      }
    }
    .alert("listening_history_missing_item_title", isPresented: $showMissingItemAlert) {
      Button("ok_button", role: .cancel) {}
    } message: {
      Text("listening_history_missing_item_message")
    }
    .errorAlert(error: $loadingState.error)
    .loadingOverlay(loadingState.show)
  }

  @ViewBuilder
  private func row(for session: SimpleListeningSession) -> some View {
    let presentation = viewModel.presentation(for: session)
    let artworkItem = viewModel.artworkItem(for: presentation)
    let isSelected = viewModel.selectedIds.contains(session.id)

    ListeningHistoryRowView(
      session: session,
      presentation: presentation,
      artworkItem: artworkItem,
      isSelected: isSelected,
      isEditing: viewModel.editMode.isEditing
    )
    .contentShape(Rectangle())
    .onTapGesture {
      if viewModel.editMode.isEditing {
        viewModel.toggleSelection(for: session.id)
      } else if viewModel.canLoad(presentation) {
        loadPlayer(with: presentation.loadRelativePath)
      } else {
        showMissingItemAlert = true
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button(role: .destructive) {
        sessionToDelete = session
      } label: {
        Image(systemName: "trash")
      }
      .tint(.red)
      .accessibilityLabel("delete_button")
    }
  }

  private func loadPlayer(with relativePath: String) {
    Task {
      do {
        loadingState.show = true
        try await playerLoaderService.loadPlayer(relativePath, autoplay: true)
        playerState.showPlayerBinding.wrappedValue = true
        loadingState.show = false
      } catch {
        loadingState.show = false
        loadingState.error = error
      }
    }
  }
}
