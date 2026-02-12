//
//  BPDialogModifier.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 11/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import SwiftUI

struct BPDialogModifier: ViewModifier {
    @Binding var dialogContent: BPAlertContent?

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                dialogContent?.title ?? "",
                isPresented: Binding(
                    get: { dialogContent != nil },
                    set: { if !$0 { dialogContent = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let dialog = dialogContent {
                    ForEach(dialog.actionItems, id: \.title) { item in
                        Button(item.title, role: role(for: item.style)) {
                            item.handler()
                            dialogContent = nil
                        }
                        .disabled(!item.isEnabled)
                    }
                }
            } message: {
                if let message = dialogContent?.message {
                    Text(message)
                }
            }
    }

    private func role(for style: UIAlertAction.Style) -> ButtonRole? {
        switch style {
        case .destructive: return .destructive
        case .cancel: return .cancel
        default: return nil
        }
    }
}

extension View {
    func bpDialog(_ dialogContent: Binding<BPAlertContent?>) -> some View {
        modifier(BPDialogModifier(dialogContent: dialogContent))
    }
}
