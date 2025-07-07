//
//  HardcoverBookPickerView.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/28/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct HardcoverBookPickerView: View {
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var themeViewModel: ThemeViewModel

  @ObservedObject var viewModel: HardcoverBookPickerView.Model

  var body: some View {
      Group {
        switch viewModel.loading {
        case .fetching:
          VStack(spacing: Spacing.S) {
            ProgressView()
            Text("hardcover_searching_books".localized)
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          
        case .loaded:
          List {
            ForEach(viewModel.rows, id: \.id) { row in
              HardcoverBookRow(viewModel: row)
                .onTapGesture {
                  viewModel.onRowTapped(row)
                  dismiss()
                }
            }
          }
          .listStyle(.plain)

        case .error(let message):
          VStack(spacing: Spacing.S) {
            Image(systemName: "exclamationmark.triangle")
              .font(.system(size: 48))
              .foregroundColor(.red)
              .accessibilityHidden(true)
            
            Text("hardcover_error_title".localized)
              .font(.headline)
            
            Text(message)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    .onAppear(perform: viewModel.onAppear)
    .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("hardcover_unlink_button".localized) {
              viewModel.onUnlinkTapped()
              dismiss()
            }
        }
    }
    .searchable(text: $viewModel.searchQuery, placement: .toolbar)
    .onChange(of: viewModel.searchQuery, perform: { viewModel.onSearch($0) })
    .tint(themeViewModel.linkColor)
  }
}

extension HardcoverBookPickerView {
  class Model: ObservableObject, Identifiable {    
    let id = UUID()

    enum Loading: Equatable {
      case fetching
      case loaded
      case error(String)
    }
    @Published var loading: Loading
    @Published var rows: [HardcoverBookRow.Model]
    @Published var selected: HardcoverBookRow.Model?
    @Published var searchQuery: String = ""

    @MainActor
    func onSearch(_ query: String) {}

    @MainActor
    func onAppear() {}

    @MainActor
    func onUnlinkTapped() {}

    @MainActor
    func onRowTapped(_ row: HardcoverBookRow.Model) {}

    init(loading: Loading = .fetching, rows: [HardcoverBookRow.Model] = []) {
      self.loading = loading
      self.rows = rows
    }
  }
}

#Preview("default") {
  NavigationStack {
    HardcoverBookPickerView(
      viewModel: HardcoverBookPickerView.Model(
        loading: .loaded,
        rows:
          [
            .init(
              id: 445742,
              artworkURL: URL(string: "https://assets.hardcover.app/books/445742/8509306724298071.jpg"),
              title: "Awaken Online: Catharsis",
              author: "Travis Bagwell"
            ),
            .init(
              id: 445750,
              artworkURL: URL(string: "https://assets.hardcover.app/books/445750/1174411997627922.jpg"),
              title: "Awaken Online: Precipice",
              author: "Travis Bagwell"
            ),
            .init(
              id: 445751,
              artworkURL: URL(string: "https://assets.hardcover.app/books/445751/4202370980567338.jpg"),
              title: "Awaken Online Side Quest: Unity",
              author: "Travis Bagwell"
            ),
            .init(
              id: 770271,
              artworkURL: URL(string: "https://assets.hardcover.app/editions/30772001/7722000416238783.jpg"),
              title: "Awaken Online Side Quest: Retribution",
              author: "Travis Bagwell"
            ),
            .init(
              id: 1433478,
              artworkURL: URL(string: "https://assets.hardcover.app/edition/31470331/a1e3c468c4422b1bad2b729122939487458fc9bc.jpeg"),
              title: "Awaken Online: Hellion",
              author: "Travis Bagwell"
            )
          ]
      )
    )
  }
  .environmentObject(ThemeViewModel())
}
