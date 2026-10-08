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

  @State private var isEnabled = false
  @State private var copied = false

  var body: some View {
    Form {
      ThemedSection {
        Toggle(
          isOn: Binding(
            get: { isEnabled },
            set: { newValue in
              isEnabled = newValue
              if newValue {
                wifiTransferServer.start()
              } else {
                wifiTransferServer.stop()
              }
            }
          )
        ) {
          Text("wifi_transfer_toggle_title".localized)
            .foregroundStyle(theme.primaryColor)
        }
        .accessibilityLabel("wifi_transfer_toggle_title".localized)
      } footer: {
        Text("wifi_transfer_footer".localized)
          .foregroundStyle(theme.secondaryColor)
      }

      if !networkMonitor.isConnectedViaWiFi {
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
      if isEnabled, !wifiTransferServer.isRunning {
        wifiTransferServer.start()
      }
    }
    .onDisappear {
      isEnabled = false
      wifiTransferServer.stop()
    }
    .onChange(of: wifiTransferServer.status) { _, newStatus in
      switch newStatus {
      case .failed:
        isEnabled = false
      case .stopped:
        isEnabled = false
      case .running:
        copied = false
      case .starting:
        break
      }
    }
  }
}

#Preview {
  NavigationStack {
    WifiTransferView()
  }
  .environmentObject(ThemeViewModel())
  .environmentObject(WifiTransferServer())
}
