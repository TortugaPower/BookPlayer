//
//  ProfileView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 11/11/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct ProfileView: View {
  @ForcedEnvironment(\.coreServices) var coreServices
  @Binding var account: Account?
  @State private var totalSpaceUsed: String = ""
  @State private var isLoading = false
  @State private var error: Error?

  init(account: Binding<Account?>) {
    self._account = account
    self._totalSpaceUsed = .init(initialValue: getFolderSize())
  }

  func getFolderSize() -> String {
    var folderSize: Int64 = 0
    let folderURL = DataManager.getProcessedFolderURL()

    let enumerator = FileManager.default.enumerator(
      at: folderURL,
      includingPropertiesForKeys: [],
      options: [.skipsHiddenFiles],
      errorHandler: { (url, error) -> Bool in
        print("directoryEnumerator error at \(url): ", error)
        return true
      }
    )!

    for case let fileURL as URL in enumerator {
      guard let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) else { continue }
      folderSize += fileAttributes[FileAttributeKey.size] as? Int64 ?? 0
    }

    return ByteCountFormatter.string(
      fromByteCount: folderSize,
      countStyle: ByteCountFormatter.CountStyle.file
    )
  }

  func deleteFolder() throws {
    // Delete file item if it exists
    let folderURL = DataManager.getProcessedFolderURL()
    if FileManager.default.fileExists(atPath: folderURL.path) {
      try FileManager.default.removeItem(at: folderURL)
    }
    /// Recreate folder
    _ = DataManager.getProcessedFolderURL()
    totalSpaceUsed = getFolderSize()
  }

  var body: some View {
    List {
      Section {
        if !coreServices.hasSyncEnabled {
          Text("subscription_required_title".localized)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
        }

        Button {
          do {
            isLoading = true
            try deleteFolder()
            try coreServices.accountService.logout()
            isLoading = false
            account = nil
            coreServices.hasSyncEnabled = false
          } catch {
            isLoading = false
            self.error = error
          }
        } label: {
          Text("logout_title".localized)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(PlainButtonStyle())
        .foregroundStyle(.red)
        .listRowBackground(Color.clear)
      } header: {
        if let email = coreServices.accountService.getAccount()?.email {
          Text(verbatim: email)
            .foregroundStyle(.secondary)
        }
      }

      Section {
        Text(totalSpaceUsed)
          .frame(maxWidth: .infinity, alignment: .center)
          .listRowBackground(Color.clear)
        Button {
          do {
            isLoading = true
            try deleteFolder()
            isLoading = false
          } catch {
            isLoading = false
            self.error = error
          }
        } label: {
          Text("delete_button".localized)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(PlainButtonStyle())
        .foregroundStyle(.red)
        .listRowBackground(Color.clear)
      } header: {
        Text("storage_total_title".localized)
          .foregroundStyle(.secondary)
      }
    }
    .environment(\.defaultMinListRowHeight, 30)
    .errorAlert(error: $error)
    .overlay {
      Group {
        if isLoading {
          ProgressView()
            .tint(.white)
            .padding()
            .background(
              Color.black
                .opacity(0.9)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            )
        }
      }
    }
  }
}
