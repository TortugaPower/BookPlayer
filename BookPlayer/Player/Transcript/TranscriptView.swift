//
//  TranscriptView.swift
//  BookPlayer
//
//  Created by Codex on 3/2/26.
//

import SwiftUI

struct TranscriptView: View {
    @EnvironmentObject private var theme: ThemeViewModel

    let lines: [TranscriptLine]
    let activeIndex: Int?
    let onLineTap: (TranscriptLine) -> Void
    let scrollRequest: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        transcriptRow(index: index, line: line)
                            .id(index)
                    }
                }
                .padding(16)
            }
            .onAppear {
                scrollToActiveLine(using: proxy)
            }
            .onChange(of: activeIndex) { _ in
                scrollToActiveLine(using: proxy)
            }
            .onChange(of: scrollRequest) { _ in
                scrollToActiveLine(using: proxy)
            }
        }
        .background(theme.secondarySystemBackgroundColor)
        .accessibilityElement(children: .contain)
    }

    private func transcriptRow(index: Int, line: TranscriptLine) -> some View {
        let isActive = index == activeIndex

        return Text(line.text)
            .bpFont(isActive ? .title2 : .body)
            .foregroundColor(isActive ? theme.linkColor : theme.primaryColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? theme.tertiarySystemBackgroundColor : Color.clear)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onLineTap(line)
            }
    }

    private func scrollToActiveLine(using proxy: ScrollViewProxy) {
        guard let activeIndex else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(activeIndex, anchor: .center)
        }
    }
}

#Preview {
    TranscriptView(
        lines: [
            TranscriptLine(time: 0, text: "Chapter one"),
            TranscriptLine(time: 4, text: "It was a bright cold day in April."),
            TranscriptLine(time: 9, text: "The clocks were striking thirteen."),
        ],
        activeIndex: 1,
        onLineTap: { _ in },
        scrollRequest: 0
    )
    .environmentObject(ThemeViewModel())
}
