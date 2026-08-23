//
//  SyncInvitationCard.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/4/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import BookPlayerKit

struct SyncInvitationCard: View {
  let totalItems: Int
  let subscription: AccessLevel
  let onDownload: () -> Void
  let onSync: () -> Void
  let onCancel: () -> Void
  
  var body: some View {
    VStack(spacing: 24) {
      Image(systemName: (subscription == .pro || subscription == .lite) ? "arrow.down.circle.fill" : "cloud.sun.fill")
        .resizable()
        .scaledToFit()
        .frame(width: 64, height: 64)
        .foregroundStyle(.white, .orange)
        .padding(.top, 16)
      
      if !(subscription == .pro || subscription == .lite) {
        VStack(spacing: 8) {
          Text("sync_invitation_save_storage_title".localized)
            .font(.title2)
            .fontWeight(.bold)
            .multilineTextAlignment(.center)
        }
      }
        
      Text(String(format: "sync_invitation_description".localized, 
                  (subscription == .lite ? "import_verb" : "download_verb").localized, 
                  totalItems, 
                  ((subscription == .pro || subscription == .lite) ? "" : "sync_invitation_stream_description".localized)))
          .font(.subheadline)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      
      VStack(spacing: 12) {
        if !(subscription == .pro || subscription == .lite) {
          Button {
            onSync()
          } label: {
            HStack {
              Text("sync_invitation_learn_more_button".localized)
                .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(14)
          }
          .accessibilityLabel("Learn more")
          .accessibilityHint("Learn more about streaming and syncing items from your server.")
        }
        
        Button {
          onDownload()
        } label: {
          Text(subscription == .lite ? "import_button".localized : "download_title".localized)
            .fontWeight(.medium)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.secondary.opacity(0.15))
            .foregroundColor(.primary)
            .cornerRadius(14)
        }
        .accessibilityLabel(subscription == .lite ? "Import" : "Download Locally")
        .accessibilityHint(subscription == .lite ? "Import \(totalItems) items to your library." : "Download \(totalItems) items to your device storage.")
      }
    }
    .padding(24)
    .background(Color(UIColor.secondarySystemGroupedBackground))
    .cornerRadius(24)
    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
    .overlay(alignment: .topLeading) {
      Button(action: onCancel) {
        Image(systemName: "xmark.circle.fill")
          .font(.title2)
          .foregroundStyle(.tertiary)
          .frame(width: 44, height: 44)
      }
      .padding(16)
      .accessibilityLabel("Close")
      .accessibilityHint("Dismisses the invitation card.")
    }
  }
}
