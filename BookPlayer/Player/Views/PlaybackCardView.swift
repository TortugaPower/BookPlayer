//
//  PlaybackCardView.swift
//  BookPlayer
//
//  Created by Codex on 3/2/26.
//

import SwiftUI

struct PlaybackCardView: View {
    let title: String
    let author: String
    let imagePath: String?
    let transcriptLines: [TranscriptLine]
    let activeTranscriptIndex: Int?
    let isShowingTranscript: Bool
    let onTranscriptToggle: () -> Void
    let onTranscriptLineTap: (TranscriptLine) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if isShowingTranscript, !transcriptLines.isEmpty {
                    TranscriptView(
                        lines: transcriptLines,
                        activeIndex: activeTranscriptIndex,
                        onLineTap: onTranscriptLineTap
                    )
                } else {
                    ArtworkView(
                        title: title,
                        author: author,
                        imagePath: imagePath
                    )
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .cornerRadius(12)
            .clipped()

            transcriptButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var transcriptButton: some View {
        Button(action: onTranscriptToggle) {
            Image(systemName: "note.text")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.black.opacity(isShowingTranscript ? 0.6 : 0.35))
                )
                .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
        }
        .padding(.leading, 8)
        .padding(.top, 8)
        .accessibilityLabel(Text("Read along"))
    }
}

#Preview {
    PlaybackCardView(
        title: "Sample",
        author: "Author",
        imagePath: nil,
        transcriptLines: [
            TranscriptLine(time: 0, text: "Line one"),
            TranscriptLine(time: 5, text: "Line two"),
        ],
        activeTranscriptIndex: 1,
        isShowingTranscript: true,
        onTranscriptToggle: {},
        onTranscriptLineTap: { _ in }
    )
    .environmentObject(ThemeViewModel())
}
