//
//  ListeningHistoryRowView.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ListeningHistoryRowView: View {
  let session: SimpleListeningSession
  let presentation: ListeningHistoryPresentation
  let artworkItem: SimpleLibraryItem?
  let isSelected: Bool
  let isEditing: Bool

  @EnvironmentObject private var theme: ThemeViewModel
  @Environment(\.syncService) private var syncService

  private var timeRangeText: String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .none
    let start = formatter.string(from: session.startedAt)
    if let endedAt = session.endedAt {
      return "\(start) – \(formatter.string(from: endedAt))"
    }
    return start
  }

  private var durationText: String {
    TimeParser.formatTime(session.duration)
  }

  private var accessibilitySummary: String {
    var parts = [presentation.title]
    if let subtitle = presentation.subtitle {
      parts.append(subtitle)
    }
    parts.append(durationText)
    parts.append(timeRangeText)
    return parts.joined(separator: ", ")
  }

  var body: some View {
    HStack(spacing: Spacing.S) {
      if isEditing {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(isSelected ? theme.linkColor : theme.secondaryColor)
          .accessibilityHidden(true)
      }

      artwork
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

      VStack(alignment: .leading, spacing: 2) {
        Text(verbatim: presentation.title)
          .bpFont(.subheadline)
          .fontWeight(.semibold)
          .foregroundStyle(theme.primaryColor)
          .lineLimit(2)

        if let subtitle = presentation.subtitle, !subtitle.isEmpty {
          Text(verbatim: subtitle)
            .bpFont(.caption)
            .foregroundStyle(theme.secondaryColor)
            .lineLimit(1)
        }

        Text(verbatim: timeRangeText)
          .bpFont(.caption)
          .foregroundStyle(theme.secondaryColor)
        Text(verbatim: durationText)
          .bpFont(.caption)
          .foregroundStyle(theme.secondaryColor)
      }

      Spacer(minLength: 0)
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilitySummary)
  }

  @ViewBuilder
  private var artwork: some View {
    if let artworkItem {
      ItemArtworkView(
        item: artworkItem,
        isHighlighted: false,
        syncService: syncService
      )
    } else if let artwork = theme.defaultArtwork {
      artwork
        .resizable()
        .aspectRatio(contentMode: .fill)
    } else {
      theme.systemGroupedBackgroundColor
    }
  }
}
