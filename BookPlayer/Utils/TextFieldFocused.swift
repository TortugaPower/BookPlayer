//  Copyright (c) 2023 chavanakshay
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//
//  TextFieldFocused.swift
//  FocusStateDemo
//
//  Created by Akshay Diliprao Chavan on 02/08/23.
//  Modified by Lysann Tranvouez on 2024-11-24.
//


import SwiftUI


protocol Focusable: Hashable {
}

@available(iOS 15.0, *)
private struct TextFieldFocused<FocusableType:Equatable & Focusable>: ViewModifier {
    
    @FocusState private var focused: Bool
    @Binding private var externalFocused: FocusableType
    private var selfkey:FocusableType
    
    init(externalFocused: Binding<FocusableType>, selfKey:FocusableType) {
        self._externalFocused = externalFocused
        self.selfkey = selfKey
        self.focused = false
    }
    
    func body(content: Content) -> some View {
        content
            .onChange(of: externalFocused) { newValue in
              focused = (newValue.hashValue == selfkey.hashValue)
            }
            .focused($focused)
            .onChange(of: focused) { isFocused in
                if isFocused {
                    externalFocused = selfkey
                }
            }
    }
}


extension View {
    
    @ViewBuilder
    func focused<FocusableType:Equatable & Focusable>(_ externalFocused: Binding<FocusableType>, selfKey:FocusableType) -> some View {
        if #available(iOS 15.0, *) {
            self.modifier(TextFieldFocused(externalFocused: externalFocused, selfKey: selfKey))
        } else {
            self
        }
    }
}
