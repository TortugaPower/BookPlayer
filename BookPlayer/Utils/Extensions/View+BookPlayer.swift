//
//  View+BookPlayer.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-11-10.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import SwiftUI

// MARK: - Keyboard Observer

final class KeyboardObserver: ObservableObject {
  @Published var isKeyboardVisible = false

  private var cancellables = Set<AnyCancellable>()

  init() {
    NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.isKeyboardVisible = true
      }
      .store(in: &cancellables)

    NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.isKeyboardVisible = false
      }
      .store(in: &cancellables)
  }
}

extension View {
  @ViewBuilder
  func defaultFormBackground() -> some View {
    scrollContentBackground(.hidden)
  }
}

struct UIFontModifier: ViewModifier {
  let uiFont: UIFont

  func body(content: Content) -> some View {
    content.font(Font(uiFont))
  }
}

extension View {
  func bpFont(_ font: UIFont) -> some View {
    self.modifier(UIFontModifier(uiFont: font))
  }
}

extension View {
  func disabledWithOpacity(_ condition: Bool, opacity: Double = 0.5) -> some View {
    self
      .disabled(condition)
      .opacity(condition ? opacity : 1)
  }

  /// Applies tint only when `enabled` is true (used for menu items)
  @ViewBuilder
  func menuTint(_ color: Color, enabled: Bool) -> some View {
    if enabled {
      self.tint(color)
    } else {
      self
    }
  }
}

struct ItemListSearchableModifier: ViewModifier {
  @Binding var text: String
  @Binding var isSearchFocused: Bool
  let prompt: String
  @Binding var selectedScope: ItemListSearchScope

  func body(content: Content) -> some View {
    if #available(iOS 26.0, *), UIDevice.current.userInterfaceIdiom == .phone {
      /// New tab bar role handles searches
      content
    } else {
      content
        .searchable(
          text: $text,
          isPresented: $isSearchFocused,
          prompt: prompt
        )
        .searchScopes($selectedScope) {
          ForEach(ItemListSearchScope.allCases) { scope in
            Text(scope.title).tag(scope)
          }
        }
    }
  }
}

extension View {
  func bpSearchable(
    text: Binding<String>,
    isSearchFocused: Binding<Bool>,
    prompt: String,
    selectedScope: Binding<ItemListSearchScope>
  ) -> some View {
    self.modifier(
      ItemListSearchableModifier(
        text: text,
        isSearchFocused: isSearchFocused,
        prompt: prompt,
        selectedScope: selectedScope
      )
    )
  }
}

struct MiniPlayerSafeAreaInsetModifier: ViewModifier {
  @Environment(\.playerState) var playerState
  @StateObject private var keyboardObserver = KeyboardObserver()

  private var spacerHeight: CGFloat {
    // When keyboard is visible, let iOS handle the safe area adjustment
    guard !keyboardObserver.isKeyboardVisible else { return 0 }

    return playerState.loadedBookRelativePath != nil ? 80 : Spacing.M
  }

  func body(content: Content) -> some View {
    if #available(iOS 26.1, *) {
      content
        .safeAreaInset(edge: .bottom) {
          Spacer().frame(height: spacerHeight)
        }
    } else if #available(iOS 26.0, *) {
      /// New accessory view already insets the entire view
      content
        .safeAreaInset(edge: .bottom) {
          Spacer().frame(height: keyboardObserver.isKeyboardVisible ? 0 : Spacing.M)
        }
    } else {
      content
        .safeAreaInset(edge: .bottom) {
          Spacer().frame(height: spacerHeight)
        }
    }
  }
}

extension View {
  func miniPlayerSafeAreaInset() -> some View {
    self.modifier(MiniPlayerSafeAreaInsetModifier())
  }
}

extension View {
  func applyListStyle(
    with theme: ThemeViewModel,
    background: Color
  ) -> some View {
    self
      .contentMargins(.top, Spacing.S1, for: .scrollContent)
      .scrollContentBackground(.hidden)
      .background(background)
      .toolbarColorScheme(theme.useDarkVariant ? .dark : .light, for: .navigationBar)
  }
}

// MARK: - Toolbar utils

struct MiniPlayerModifier<Regular: View, Accessory: View>: ViewModifier {
  @ViewBuilder let regular: () -> Regular
  @ViewBuilder let accessory: () -> Accessory

  func body(content: Content) -> some View {
    if #available(iOS 26.1, *) {
      content
        .safeAreaInset(edge: .bottom, spacing: 0, content: regular)
    } else if #available(iOS 26.0, *) {
      content
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(content: accessory)
    } else {
      content
        .safeAreaInset(edge: .bottom, spacing: 0, content: regular)
    }
  }
}
extension View {
  func miniPlayer<Regular: View, Accessory: View>(
    @ViewBuilder regularContent: @escaping () -> Regular,
    @ViewBuilder accessoryContent: @escaping () -> Accessory
  ) -> some View {
    self.modifier(MiniPlayerModifier<Regular, Accessory>(regular: regularContent, accessory: accessoryContent))
  }
}

extension View {
  func formatSpeed(_ speed: Double) -> String {
    return (speed.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(speed))" : "\(speed)") + "×"
  }
}

extension View {
  @ViewBuilder
  func liquidGlassBackground() -> some View {
    if #available(iOS 26.0, *) {
      glassEffect()
    } else {
      background(.ultraThinMaterial)
    }
  }
}
