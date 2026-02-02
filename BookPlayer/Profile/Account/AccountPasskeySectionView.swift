//
//  AccountPasskeySectionView.swift
//  BookPlayer
//
//  Created by Claude on 1/10/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct AccountPasskeySectionView: View {
  @State private var passkey: PasskeyInfo?
  @State private var isLoading = false
  @State private var loadFailed = false
  @State private var error: Error?
  @State private var showDeleteConfirmation = false

  @EnvironmentObject private var theme: ThemeViewModel
  @Environment(\.accountService) private var accountService
  @Environment(\.passkeyService) private var passkeyService

  var body: some View {
    Section {
      if isLoading {
        loadingView
      } else if let passkey = passkey {
        passkeyRow(passkey)
      } else if loadFailed {
        retryButton
      } else {
        addButton
      }
    } header: {
      Text("Passkey")
        .foregroundStyle(theme.secondaryColor)
    }
    .onAppear {
      Task {
        await loadPasskey()
      }
    }
    .errorAlert(error: $error)
    .alert("passkey_delete_title".localized, isPresented: $showDeleteConfirmation) {
      Button("cancel_button".localized, role: .cancel) {}
      Button("delete_button".localized, role: .destructive) {
        if let passkey = passkey {
          Task {
            await deletePasskey(id: passkey.id)
          }
        }
      }
    } message: {
      Text("passkey_delete_message".localized)
    }
  }

  @ViewBuilder
  private var loadingView: some View {
    HStack {
      Spacer()
      ProgressView()
      Spacer()
    }
  }

  @ViewBuilder
  private func passkeyRow(_ passkey: PasskeyInfo) -> some View {
    HStack(spacing: Spacing.S) {
      Image(systemName: "person.badge.key")
        .bpFont(.title2)
        .foregroundStyle(theme.linkColor)

      VStack(alignment: .leading, spacing: 4) {
        Text(passkey.deviceName ?? "passkey_unnamed_device".localized)
          .bpFont(.body)
          .foregroundStyle(theme.primaryColor)

        Text("passkey_created".localized + " " + passkey.createdAt.formatted(date: .abbreviated, time: .omitted))
          .bpFont(.caption)
          .foregroundStyle(theme.secondaryColor)
      }

      Spacer()

      Menu {
        Button(role: .destructive) {
          showDeleteConfirmation = true
        } label: {
          Label("delete_button".localized, systemImage: "trash")
        }
        .tint(.red)
      } label: {
        Image(systemName: "ellipsis.circle")
          .bpFont(.title2)
          .foregroundStyle(theme.linkColor)
          .frame(width: 44, height: 44)
      }
    }
  }

  @ViewBuilder
  private var retryButton: some View {
    Button {
      Task {
        await loadPasskey()
      }
    } label: {
      Label("network_error_title".localized, systemImage: "arrow.clockwise")
        .foregroundStyle(theme.linkColor)
    }
  }

  @ViewBuilder
  private var addButton: some View {
    Button {
      addPasskey()
    } label: {
      Label("account_add_passkey_title".localized, systemImage: "person.badge.key")
        .foregroundStyle(theme.linkColor)
    }
  }

  private func loadPasskey() async {
    isLoading = true
    loadFailed = false
    do {
      let passkeys = try await passkeyService.listPasskeys()
      // Only use the first passkey (we only support one per account)
      passkey = passkeys.first
    } catch {
      loadFailed = true
    }
    isLoading = false
  }

  private func addPasskey() {
    // Don't allow adding if one already exists
    guard passkey == nil else { return }

    Task {
      do {
        let deviceName = UIDevice.current.name
        let email = accountService.getAccount()?.email
        try await passkeyService.addPasskeyToAccount(deviceName: deviceName, email: email!)
        await loadPasskey()
      } catch PasskeyError.userCancelled {
        // User cancelled, do nothing
      } catch {
        self.error = error
      }
    }
  }

  private func deletePasskey(id: Int) async {
    do {
      try await passkeyService.deletePasskey(id: id)
      await loadPasskey()
    } catch {
      self.error = error
    }
  }
}

#Preview {
  Form {
    AccountPasskeySectionView()
  }
}
