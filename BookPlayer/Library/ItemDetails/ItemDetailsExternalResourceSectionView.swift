//
//  ItemDetailsExternalResourceSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 7/9/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ItemDetailsExternalResourceSectionView: View {
  let externalResources: [SimpleExternalResource]

  /// Resolved once on appear, keyed by providerId: resolving inside the body did a
  /// synchronous keychain read + JSON decode on every render.
  @State private var resolvedHosts: [String: String] = [:]

  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    if !externalResources.isEmpty {
      ThemedSection {
        // Sync-created resources never populate the numeric id (all default to 0),
        // so keying on Identifiable collides for multi-resource items; providerId
        // is the stable key (same pattern as BookView).
        ForEach(externalResources, id: \.providerId) { resource in
          VStack(alignment: .leading, spacing: Spacing.S1) {
            HStack {
              Text("provider_title".localized)
                .bold()
              Spacer()
              Text(resource.providerName.capitalized)
                .lineLimit(1)
            }

            HStack {
              Text("provider_id_title".localized)
                .bold()
              Spacer()
              Text(resource.providerId)
                .lineLimit(1)
            }

            if let hostId = resource.hostId, !hostId.isEmpty {
              HStack {
                Text("host_title".localized)
                  .bold()
                Spacer()
                Text(resolvedHosts[resource.providerId] ?? "")
                  .lineLimit(1)
                  .truncationMode(.tail)
              }
            }
          }
          .bpFont(.body)
          .padding(.vertical, Spacing.S1)
        }
      } header: {
        Text("external_resources_title".localized)
      }
      .onAppear {
        guard resolvedHosts.isEmpty else { return }
        resolvedHosts = externalResources.reduce(into: [:]) { hosts, resource in
          hosts[resource.providerId] = resolveHost(resource)
        }
      }
    }
  }

  private func resolveHost(_ resource: SimpleExternalResource) -> String {
    let keychainService = KeychainService()
    let hostId = resource.hostId ?? ""

    switch ExternalResource.ProviderName(rawValue: resource.providerName) {
    case .jellyfin:
      let connections: [JellyfinConnectionData] = (try? keychainService.get(.jellyfinConnection)) ?? []
      if let connection = IntegrationHostResolver.connection(for: hostId, in: connections) {
        return connection.url.absoluteString
      }
    case .audiobookshelf:
      let connections: [AudiobookShelfConnectionData] = (try? keychainService.get(.audiobookshelfConnection)) ?? []
      if let connection = IntegrationHostResolver.connection(for: hostId, in: connections) {
        return connection.url.absoluteString
      }
    default:
      break
    }

    return hostId
  }
}
