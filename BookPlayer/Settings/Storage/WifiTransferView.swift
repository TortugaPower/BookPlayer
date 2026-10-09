//
//  WifiTransferView.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct WifiTransferView: View {
  @EnvironmentObject private var theme: ThemeViewModel
  @EnvironmentObject private var wifiTransferServer: WifiTransferServer
  @Environment(\.networkMonitor) private var networkMonitor

  @AppStorage(WifiTransferFileSupport.Preferences.portKey)
  private var portStorage: Int = Int(WifiTransferFileSupport.defaultPort)

  @AppStorage(WifiTransferFileSupport.Preferences.requirePinKey)
  private var requirePin = false

  @State private var isEnabled = false
  @State private var copied = false
  @State private var displayedPin = ""
  @State private var isRestarting = false

  private var canStart: Bool {
    networkMonitor.isConnectedViaWiFi
  }

  private var clampedPortBinding: Binding<String> {
    Binding(
      get: { String(WifiTransferFileSupport.clampedPort(UInt16(clamping: portStorage))) },
      set: { newValue in
        let digits = newValue.filter(\.isNumber)
        guard let value = UInt16(digits), value > 0 else { return }
        let clamped = Int(WifiTransferFileSupport.clampedPort(value))
        guard clamped != portStorage else { return }
        portStorage = clamped
        WifiTransferFileSupport.Preferences.port = UInt16(clamped)
        restartServerIfNeeded()
      }
    )
  }

  var body: some View {
    Form {
      ThemedSection {
        Toggle(
          isOn: Binding(
            get: { isEnabled },
            set: { newValue in
              guard newValue else {
                isEnabled = false
                wifiTransferServer.stop()
                return
              }
              guard canStart else {
                isEnabled = false
                wifiTransferServer.start(isOnWiFi: false)
                return
              }
              syncPrefsToStorage()
              isEnabled = true
              wifiTransferServer.start(isOnWiFi: true)
            }
          )
        ) {
          Text("wifi_transfer_toggle_title".localized)
            .foregroundStyle(theme.primaryColor)
        }
        .disabled(!canStart && !isEnabled)
        .accessibilityLabel("wifi_transfer_toggle_title".localized)
      } footer: {
        Text("wifi_transfer_footer".localized)
          .foregroundStyle(theme.secondaryColor)
      }

      ThemedSection {
        HStack {
          Text("wifi_transfer_port_title".localized)
            .foregroundStyle(theme.primaryColor)
          Spacer()
          TextField("8080", text: clampedPortBinding)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 100)
            .foregroundStyle(theme.primaryColor)
            .accessibilityLabel("wifi_transfer_port_title".localized)
        }
      } footer: {
        Text("wifi_transfer_port_footer".localized)
          .foregroundStyle(theme.secondaryColor)
      }

      ThemedSection {
        Toggle(isOn: requirePinBinding) {
          Text("wifi_transfer_require_pin_title".localized)
            .foregroundStyle(theme.primaryColor)
        }
        .accessibilityLabel("wifi_transfer_require_pin_title".localized)

        if requirePin {
          HStack {
            Text("wifi_transfer_pin_label".localized)
              .foregroundStyle(theme.secondaryColor)
            Spacer()
            Text(displayedPin.isEmpty ? "----" : displayedPin)
              .bpFont(.title2)
              .monospacedDigit()
              .foregroundStyle(theme.primaryColor)
              .accessibilityLabel("wifi_transfer_pin_label".localized)
              .accessibilityValue(displayedPin)
          }

          Button {
            displayedPin = WifiTransferFileSupport.Preferences.regeneratePin()
            restartServerIfNeeded()
          } label: {
            Text("wifi_transfer_pin_regenerate".localized)
              .bpFont(.body)
          }
          .accessibilityLabel("wifi_transfer_pin_regenerate".localized)
        }
      } footer: {
        Text("wifi_transfer_require_pin_footer".localized)
          .foregroundStyle(theme.secondaryColor)
      }

      if !canStart {
        ThemedSection {
          Text("wifi_transfer_no_wifi_message".localized)
            .bpFont(.body)
            .foregroundStyle(theme.secondaryColor)
        }
      }

      if let url = wifiTransferServer.serverURL, wifiTransferServer.isRunning {
        ThemedSection {
          Text(url.absoluteString)
            .bpFont(.body)
            .foregroundStyle(theme.linkColor)
            .textSelection(.enabled)
            .accessibilityLabel("wifi_transfer_url_accessibility".localized)
            .accessibilityValue(url.absoluteString)

          Button {
            UIPasteboard.general.string = url.absoluteString
            copied = true
          } label: {
            Label(
              copied ? "wifi_transfer_copied_button".localized : "wifi_transfer_copy_button".localized,
              systemImage: copied ? "checkmark" : "doc.on.doc"
            )
            .bpFont(.body)
          }
          .accessibilityLabel("wifi_transfer_copy_button".localized)
        } header: {
          Text("wifi_transfer_url_header".localized)
            .bpFont(.subheadline)
            .foregroundStyle(theme.secondaryColor)
        }
      }

      if case .failed(let message) = wifiTransferServer.status {
        ThemedSection {
          Text(message)
            .bpFont(.body)
            .foregroundStyle(theme.secondaryColor)
        }
      }

      if let name = wifiTransferServer.lastUploadedFilename {
        ThemedSection {
          Text(String(format: "wifi_transfer_last_file_format".localized, name))
            .bpFont(.body)
            .foregroundStyle(theme.primaryColor)
        }
      }
    }
    .scrollContentBackground(.hidden)
    .background(theme.systemBackgroundColor)
    .navigationTitle("wifi_transfer_title".localized)
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      syncPrefsToStorage()
      refreshDisplayedPin()
      if isEnabled, canStart, !wifiTransferServer.isRunning {
        wifiTransferServer.start(isOnWiFi: true)
      }
    }
    .onDisappear {
      isEnabled = false
      wifiTransferServer.stop()
    }
    .onChange(of: canStart) { _, onWiFi in
      if !onWiFi, isEnabled {
        isEnabled = false
        wifiTransferServer.stop()
      }
    }
    .onChange(of: wifiTransferServer.status) { _, newStatus in
      switch newStatus {
      case .failed:
        isEnabled = false
      case .stopped:
        if !isRestarting {
          isEnabled = false
        }
      case .running:
        copied = false
        isRestarting = false
      case .starting:
        break
      }
    }
    .onChange(of: requirePin) { _, _ in
      refreshDisplayedPin()
    }
  }

  private var requirePinBinding: Binding<Bool> {
    Binding(
      get: { requirePin },
      set: { newValue in
        requirePin = newValue
        WifiTransferFileSupport.Preferences.requirePin = newValue
        if newValue {
          displayedPin = WifiTransferFileSupport.Preferences.pin ?? WifiTransferFileSupport.Preferences.regeneratePin()
        } else {
          displayedPin = ""
        }
        restartServerIfNeeded()
      }
    )
  }

  private func syncPrefsToStorage() {
    WifiTransferFileSupport.Preferences.port = WifiTransferFileSupport.clampedPort(
      UInt16(clamping: portStorage)
    )
    WifiTransferFileSupport.Preferences.requirePin = requirePin
    if requirePin {
      _ = WifiTransferFileSupport.Preferences.pin
    }
  }

  private func refreshDisplayedPin() {
    displayedPin = requirePin ? (WifiTransferFileSupport.Preferences.pin ?? "") : ""
  }

  private func restartServerIfNeeded() {
    guard isEnabled, canStart else { return }
    syncPrefsToStorage()
    isRestarting = true
    wifiTransferServer.stop()
    wifiTransferServer.start(isOnWiFi: true)
  }
}

#Preview {
  NavigationStack {
    WifiTransferView()
  }
  .environmentObject(ThemeViewModel())
  .environmentObject(WifiTransferServer())
}
