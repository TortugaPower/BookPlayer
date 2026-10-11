//
//  ItemDetailsIntegrationsSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 7/9/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

/// The item's integrations, named as in Settings: its Hardcover link, and the media servers it
/// streams from. A media-server row names the integration and its server; tapping it opens the
/// Media Servers list (`onOpenMediaServers`), not that server's library: landing straight in a
/// library from here could look like picking another book for this item.
struct ItemDetailsIntegrationsSectionView: View {
  let hardcover: ItemDetailsHardcoverSectionView.Model?
  let mediaServerResources: [SimpleExternalResource]
  /// Keyed by providerId; resolved by ItemDetailsViewModel off the main thread —
  /// this view renders data and holds no keychain dependency.
  let resolvedHosts: [String: String]
  let onOpenMediaServers: () -> Void

  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    ThemedSection {
      if let hardcover {
        ItemDetailsHardcoverSectionView(viewModel: hardcover)
      }

      // Sync-created resources never populate the numeric id (all default to 0),
      // so keying on Identifiable collides for multi-resource items; providerId
      // is the stable key (same pattern as BookView).
      ForEach(mediaServerResources, id: \.providerId) { resource in
        Button {
          onOpenMediaServers()
        } label: {
          HStack(spacing: Spacing.S1) {
            Text(resource.mediaServer?.displayName ?? resource.providerName.capitalized)
              .foregroundStyle(theme.primaryColor)
            Spacer()
            Text(host(of: resource))
              .foregroundStyle(theme.secondaryColor)
              .lineLimit(1)
              .truncationMode(.middle)
            Image(systemName: "chevron.right")
              .font(.footnote.weight(.semibold))
              .foregroundStyle(theme.secondaryColor)
              .accessibilityHidden(true)
          }
          .bpFont(.body)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    } header: {
      Text("integrations_title")
    }
  }

  /// The server's host from its saved connection, else the raw `hostId`: what resolution itself
  /// falls back to for a server not set up on this device, so the row always names one.
  private func host(of resource: SimpleExternalResource) -> String {
    let address = resolvedHosts[resource.providerId] ?? resource.hostId ?? ""
    return URL(string: address)?.host ?? address
  }
}
