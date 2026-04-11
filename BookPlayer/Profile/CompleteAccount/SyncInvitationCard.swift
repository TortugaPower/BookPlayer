//
//  SyncInvitationCard.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/4/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct SyncInvitationCard: View {
  let totalItems: Int
  let hasSubscription: Bool
  let onDownload: () -> Void
  let onSync: () -> Void
  let onCancel: () -> Void
  
  var body: some View {
    VStack(spacing: 24) {
      Image(systemName: hasSubscription ? "arrow.down.circle.fill" : "cloud.sun.fill")
        .resizable()
        .scaledToFit()
        .frame(width: 64, height: 64)
        .foregroundStyle(.white, .orange)
        .padding(.top, 16)
      
      VStack(spacing: 8) {
        Text("Save Your Storage!")
          .font(.title2)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)
        
        Text("You're about to \(hasSubscription ? "import" : "download") \(totalItems) items. \(hasSubscription ? "" : "Instead of taking up space, stream them directly from your server and keep your progress synced.")")
          .font(.subheadline)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }
      
      VStack(spacing: 12) {
        if !hasSubscription {
          Button {
            onSync()
          } label: {
            HStack {
              Image(systemName: "arrow.triangle.2.circlepath")
              Text("Stream & Sync")
                .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(14)
          }
        }
        
        Button {
          onDownload()
        } label: {
          Text(hasSubscription ? "Import" : "Download Locally")
            .fontWeight(.medium)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.secondary.opacity(0.15))
            .foregroundColor(.primary)
            .cornerRadius(14)
        }
      }
    }
    .padding(24)
    .background(Color(UIColor.secondarySystemGroupedBackground))
    .cornerRadius(24)
    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
    .overlay(alignment: .topTrailing) {
      Button(action: onCancel) {
        Image(systemName: "xmark.circle.fill")
          .font(.title2)
          .foregroundStyle(.tertiary)
      }
      .padding(16)
    }
  }
}
