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

extension View {
  /// Applies a BPFont style with automatic Dynamic Type support
  /// On iOS: Uses native SwiftUI fonts that respond to system Dynamic Type
  /// On macOS: Applies manual scaling based on user's text size preference
  func bpFont(_ style: BPFont) -> some View {
    self.modifier(BPFontModifier(style: style))
  }
}

// MARK: - BPFont Modifier

/// Applies BPFont with platform-specific scaling
/// iOS: Native Dynamic Type via SwiftUI text styles
/// macOS: Manual scaling using user preference from Settings
struct BPFontModifier: ViewModifier {
  let style: BPFont

  @AppStorage(Constants.UserDefaults.macOSTextScale)
  private var textScaleIndex: Double = 0.0

  private var isMacOS: Bool {
    ProcessInfo.processInfo.isiOSAppOnMac
  }

  /// Scale factor for macOS (1.0 to 1.6 based on slider position 0-6)
  private var macOSScaleFactor: CGFloat {
    Self.macOSScaleFactor(forIndex: textScaleIndex)
  }

  /// The Text Size setting's factor on a Mac, where it stands in for Dynamic Type
  static func macOSScaleFactor(forIndex index: Double) -> CGFloat {
    1.0 + (index * 0.1)
  }

  func body(content: Content) -> some View {
    if isMacOS {
      content.font(style.scaledFont(by: macOSScaleFactor))
    } else {
      content.font(style.font)
    }
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
  @StateObject private var keyboardObserver = KeyboardObserver()

  /// The tab view's bottom accessory already insets the content for the mini player
  func body(content: Content) -> some View {
    content
      .safeAreaInset(edge: .bottom) {
        Spacer().frame(height: keyboardObserver.isKeyboardVisible ? 0 : Spacing.M)
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

// MARK: - Mini Player

struct MiniPlayerModifier<Accessory: View>: ViewModifier {
  let isEnabled: Bool
  @ViewBuilder let accessory: () -> Accessory

  func body(content: Content) -> some View {
    if #available(iOS 26.1, *) {
      /// Since 26.1 an accessory with empty content still shows as an empty bar
      content
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: isEnabled, content: accessory)
    } else {
      /// 26.0 hides the accessory when its content is empty
      content
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
          if isEnabled {
            accessory()
          }
        }
    }
  }
}

extension View {
  func miniPlayer<Accessory: View>(
    isEnabled: Bool,
    @ViewBuilder content: @escaping () -> Accessory
  ) -> some View {
    self.modifier(MiniPlayerModifier(isEnabled: isEnabled, accessory: content))
  }
}

extension View {
  func formatSpeed(_ speed: Double) -> String {
    return (speed.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(speed))" : "\(speed)") + "×"
  }
}

extension View {
  /// Applies a context menu only when running as an iOS app on macOS ("Designed for iPad").
  /// Use this to add right-click support on Mac without affecting iOS long-press behavior.
  @ViewBuilder
  func macContextMenu<MenuItems: View>(@ViewBuilder menuItems: () -> MenuItems) -> some View {
    if ProcessInfo.processInfo.isiOSAppOnMac {
      self.contextMenu { menuItems() }
    } else {
      self
    }
  }

  /// Selection-based variant for Lists. The menu closure receives the set of item IDs
  /// that were right-clicked, without mutating any state during view evaluation.
  @ViewBuilder
  func macContextMenu<ID: Hashable, MenuItems: View>(
    forSelectionType type: ID.Type,
    @ViewBuilder menu: @escaping (Set<ID>) -> MenuItems
  ) -> some View {
    if ProcessInfo.processInfo.isiOSAppOnMac {
      self.contextMenu(forSelectionType: type, menu: menu)
    } else {
      self
    }
  }
}

extension View {
  /// Glass in an explicit rounded rect rather than the default capsule, for panels that span
  /// a width instead of floating as a pill.
  func glassCard(cornerRadius: CGFloat = 16) -> some View {
    glassEffect(in: .rect(cornerRadius: cornerRadius))
  }

  func liquidGlassBackground() -> some View {
    glassEffect()
  }
}
