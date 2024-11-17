//
//  ProfileView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 11/11/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI

struct ProfileView: View {
  @StateObject var model = ProfileViewModel()
  @State private var isLoading = false
  @State private var error: Error?
  @AppStorage("userEmail")
  var email: String?

  var body: some View {
    VStack {
      Image(systemName: "person.crop.circle")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 45, height: 45)
      if let email {
        Text(verbatim: email)
      }
      Spacer()
      Button("Log Out") {
        Task {
          do {
            isLoading = true
            try await model.handleLogOut()
            isLoading = false
          } catch {
            isLoading = false
            self.error = error
          }
        }
      }
      .buttonStyle(PlainButtonStyle())
      .foregroundStyle(.red)
    }
    .errorAlert(error: $error)
    .overlay {
      Group {
        if isLoading {
          ProgressView()
            .tint(.white)
            .padding()
            .background(
              Color.black
                .opacity(0.9)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            )
        }
      }
    }
  }
}

#Preview {
  ProfileView()
}
