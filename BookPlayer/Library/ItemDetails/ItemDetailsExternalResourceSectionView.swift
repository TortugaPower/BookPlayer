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
  /// Keyed by providerId; resolved by ItemDetailsViewModel off the main thread —
  /// this view renders data and holds no keychain dependency.
  let resolvedHosts: [String: String]

  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
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
  }

}
