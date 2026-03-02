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

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(lines.indices, id: \.self) { index in
                        let line = lines[index]
                        Text(line.text)
                            .bpFont(index == activeIndex ? .title3 : .body)
                            .foregroundColor(index == activeIndex ? theme.linkColor : theme.primaryColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(index == activeIndex ? theme.tertiarySystemBackgroundColor : Color.clear)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onLineTap(line)
                            }
                            .id(index)
                    }
                }
                .padding(16)
            }
            .onChange(of: activeIndex) { newValue in
                guard let newValue else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .background(theme.secondarySystemBackgroundColor)
        .accessibilityElement(children: .contain)
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
        onLineTap: { _ in }
    )
    .environmentObject(ThemeViewModel())
}
