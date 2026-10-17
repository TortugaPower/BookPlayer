//
//  TransferServerView.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct TransferServerView: View {
  @EnvironmentObject private var theme: ThemeViewModel
  @EnvironmentObject private var transferServer: TransferServer

  @AppStorage(TransferServerSupport.Preferences.portKey)
  private var portStorage: Int = Int(TransferServerSupport.defaultPort)

  @AppStorage(TransferServerSupport.Preferences.requirePinKey)
  private var requirePin = false

  @State private var isEnabled = false
  @State private var copied = false
  @State private var displayedPin = ""

  var body: some View {
    Form {
      ThemedSection {
        Toggle(isOn: enableBinding) {
          Text("transfer_server_toggle_title".localized)
            .foregroundStyle(theme.primaryColor)
        }
        .accessibilityLabel("transfer_server_toggle_title".localized)
      } footer: {
        Text("transfer_server_footer".localized)
          .foregroundStyle(theme.secondaryColor)
      }

      ThemedSection {
        HStack {
          Text("transfer_server_port_title".localized)
            .foregroundStyle(theme.primaryColor)
          Spacer()
          TextField("8080", text: portBinding)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 100)
            .foregroundStyle(theme.primaryColor)
            .accessibilityLabel("transfer_server_port_title".localized)
        }
      } footer: {
        Text("transfer_server_port_footer".localized)
          .foregroundStyle(theme.secondaryColor)
      }

      ThemedSection {
        Toggle(isOn: requirePinBinding) {
          Text("transfer_server_require_pin_title".localized)
            .foregroundStyle(theme.primaryColor)
        }
        .accessibilityLabel("transfer_server_require_pin_title".localized)

        if requirePin {
          HStack {
            Text("transfer_server_pin_label".localized)
              .foregroundStyle(theme.secondaryColor)
            Spacer()
            Text(displayedPin.isEmpty ? "----" : displayedPin)
              .bpFont(.title2)
              .monospacedDigit()
              .foregroundStyle(theme.primaryColor)
              .accessibilityLabel("transfer_server_pin_label".localized)
              .accessibilityValue(displayedPin)
          }

          Button {
            displayedPin = TransferServerSupport.Preferences.regeneratePin()
            restartIfEnabled()
          } label: {
            Text("transfer_server_pin_regenerate".localized)
              .bpFont(.body)
          }
          .accessibilityLabel("transfer_server_pin_regenerate".localized)
        }
      } footer: {
        Text("transfer_server_require_pin_footer".localized)
          .foregroundStyle(theme.secondaryColor)
      }

      if let url = transferServer.serverURL, transferServer.isRunning {
        ThemedSection {
          Text(url.absoluteString)
            .bpFont(.body)
            .foregroundStyle(theme.linkColor)
            .textSelection(.enabled)
            .accessibilityLabel("transfer_server_url_accessibility".localized)
            .accessibilityValue(url.absoluteString)

          Button {
            UIPasteboard.general.string = url.absoluteString
            copied = true
          } label: {
            Label(
              copied ? "transfer_server_copied_button".localized : "transfer_server_copy_button".localized,
              systemImage: copied ? "checkmark" : "doc.on.doc"
            )
            .bpFont(.body)
          }
          .accessibilityLabel("transfer_server_copy_button".localized)
        } header: {
          Text("transfer_server_url_header".localized)
            .bpFont(.subheadline)
            .foregroundStyle(theme.secondaryColor)
        }
      }

      if case .failed(let message) = transferServer.status {
        ThemedSection {
          Text(message)
            .bpFont(.body)
            .foregroundStyle(theme.secondaryColor)
        }
      }

      if let name = transferServer.lastUploadedFilename {
        ThemedSection {
          Text(String(format: "transfer_server_last_file_format".localized, name))
            .bpFont(.body)
            .foregroundStyle(theme.primaryColor)
        }
      }
    }
    .scrollContentBackground(.hidden)
    .background(theme.systemBackgroundColor)
    .navigationTitle("transfer_server_title".localized)
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      syncPrefsToStorage()
      refreshDisplayedPin()
    }
    .onDisappear {
      isEnabled = false
      transferServer.stop()
    }
    .onChange(of: transferServer.status) { _, newStatus in
      switch newStatus {
      case .failed:
        isEnabled = false
      case .running:
        copied = false
      case .stopped, .starting:
        break
      }
    }
    .onChange(of: requirePin) { _, _ in
      refreshDisplayedPin()
    }
  }

  private var enableBinding: Binding<Bool> {
    Binding(
      get: { isEnabled },
      set: { turnOn in
        if turnOn {
          syncPrefsToStorage()
          isEnabled = true
          transferServer.start()
        } else {
          isEnabled = false
          transferServer.stop()
        }
      }
    )
  }

  private var portBinding: Binding<String> {
    Binding(
      get: { String(TransferServerSupport.clampedPort(UInt16(clamping: portStorage))) },
      set: { newValue in
        let digits = newValue.filter(\.isNumber)
        guard let value = UInt16(digits), value > 0 else { return }
        let clamped = Int(TransferServerSupport.clampedPort(value))
        guard clamped != portStorage else { return }
        portStorage = clamped
        TransferServerSupport.Preferences.port = UInt16(clamped)
        restartIfEnabled()
      }
    )
  }

  private var requirePinBinding: Binding<Bool> {
    Binding(
      get: { requirePin },
      set: { newValue in
        requirePin = newValue
        TransferServerSupport.Preferences.requirePin = newValue
        if newValue {
          displayedPin = TransferServerSupport.Preferences.pin
            ?? TransferServerSupport.Preferences.regeneratePin()
        } else {
          displayedPin = ""
        }
        restartIfEnabled()
      }
    )
  }

  private func syncPrefsToStorage() {
    TransferServerSupport.Preferences.port = TransferServerSupport.clampedPort(
      UInt16(clamping: portStorage)
    )
    TransferServerSupport.Preferences.requirePin = requirePin
    if requirePin {
      _ = TransferServerSupport.Preferences.pin
    }
  }

  private func refreshDisplayedPin() {
    displayedPin = requirePin ? (TransferServerSupport.Preferences.pin ?? "") : ""
  }

  private func restartIfEnabled() {
    guard isEnabled else { return }
    syncPrefsToStorage()
    transferServer.stop()
    isEnabled = true
    transferServer.start()
  }
}

#Preview {
  NavigationStack {
    TransferServerView()
  }
  .environmentObject(ThemeViewModel())
  .environmentObject(TransferServer())
}
