//
//  ItemListView+Alerts.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/10/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

// MARK: - Alert Content Builders
extension ItemListView {
  @ViewBuilder
  func alertContent(for alert: ItemListAlert) -> some View {
    switch alert {
    case .queuedTasks:
      queuedTasksAlert()
    case .moveOptions:
      moveOptionsAlert()
    case .delete:
      deleteAlert()
    case .cancelDownload(let item):
      cancelDownloadAlert(for: item)
    case .warningOffload(let item):
      warningOffloadAlert(for: item)
    case .downloadURL(let input):
      downloadURLAlert(input: input)
    }
  }
  
  // MARK: - Individual Alert Builders
  
  @ViewBuilder
  func queuedTasksAlert() -> some View {
    Button("sync_tasks_view_title") {
      activeSheet = .queuedTasks
    }
    Button("ok_button", role: .cancel) {}
  }
  
  @ViewBuilder
  func moveOptionsAlert() -> some View {
    let availableFolders = model.getAvailableFolders()
    
    if model.libraryNode != .root {
      Button("library_title") {
        model.handleMoveIntoLibrary()
      }
    }
    
    Button("new_playlist_button") {
      folderInput.reset()
      folderNameRequest = FolderNameRequest(folderInput)
    }
    
    Button("existing_playlist_button") {
      activeSheet = .foldersSelection
    }
    .disabled(availableFolders.isEmpty)

    Button("bound_books_create_button") {
      let suggestedFolderName = ((model.selectedItems.first?.title ?? "") as NSString).deletingPathExtension
      folderInput.prepareForBound(title: suggestedFolderName, placeholder: suggestedFolderName)
      folderNameRequest = FolderNameRequest(folderInput)
    }
    .disabled(!model.selectedItems.allSatisfy { $0.type == .book })

    Button("cancel_button", role: .cancel) {}
  }
  
  @ViewBuilder
  func createFolderAlert(type: SimpleItemType, placeholder: String) -> some View {
    let placeholderText = !placeholder.isEmpty
      ? placeholder
      : type == .folder
        ? "new_playlist_button".localized
        : "bound_books_new_title_placeholder".localized
    
    let selectedItems = !model.selectedSetItems.isEmpty
      ? Array(model.selectedSetItems).sorted {
        $0.localizedStandardCompare($1) == ComparisonResult.orderedAscending
      }
      : nil
    
    TextField(placeholderText, text: $folderInput.name)
    
    Button("create_button") {
      model.createFolder(
        with: folderInput.name,
        items: model.selectedItems.map { item in
          LibraryItemRef(relativePath: item.relativePath, uuid: item.uuid)
        },
        type: folderInput.type
      )
      folderInput.reset()
    }
    .disabled(folderInput.name.isEmpty)
    
    Button("cancel_button", role: .cancel) {
      folderInput.reset()
    }
  }
  
  @ViewBuilder
  func deleteAlert() -> some View {
    let canShallowDelete = model.selectedItems.count == 1
      && model.selectedItems.first?.type == .folder
    
    if canShallowDelete {
      Button("delete_deep_button", role: .destructive) {
        model.handleDelete(items: model.selectedItems, mode: .deep)
      }
      
      Button("delete_shallow_button") {
        model.handleDelete(items: model.selectedItems, mode: .shallow)
      }
    } else {
      Button("delete_button", role: .destructive) {
        model.handleDelete(items: model.selectedItems, mode: .deep)
      }
    }
    
    Button("cancel_button", role: .cancel) {}
  }
  
  @ViewBuilder
  func cancelDownloadAlert(for item: SimpleLibraryItem) -> some View {
    Button("ok_button") {
      model.cancelDownload(of: item)
    }
    Button("cancel_button", role: .cancel) {}
  }
  
  @ViewBuilder
  func warningOffloadAlert(for item: SimpleLibraryItem) -> some View {
    Text(String(format: "sync_tasks_item_upload_queued".localized, item.relativePath))
    Button("ok_button") {
      model.handleOffloading(of: item)
    }
    Button("cancel_button", role: .cancel) {}
  }
  
  @ViewBuilder
  func downloadURLAlert(input: String) -> some View {
    TextField("https://", text: $downloadURLInput)
    
    Button("download_title") {
      model.downloadFromURL(downloadURLInput)
      downloadURLInput = ""
    }
    .disabled(downloadURLInput.isEmpty)
    
    Button("cancel_button", role: .cancel) {
      downloadURLInput = ""
    }
  }
  
  // MARK: - Alert Titles
  
  func alertTitle(for alert: ItemListAlert) -> String {
    switch alert {
    case .queuedTasks:
      return "sync_tasks_inprogress_alert_title".localized
    case .moveOptions:
      return "choose_destination_title".localized
    case .delete:
      return model.deleteActionDetails()?.title ?? ""
    case .cancelDownload:
      return "cancel_download_title".localized
    case .warningOffload:
      return "warning_title".localized
    case .downloadURL:
      return "download_from_url_title".localized
    }
  }
  
  func alertMessage(for alert: ItemListAlert) -> String? {
    switch alert {
    case .delete:
      return model.deleteActionDetails()?.message
    default:
      return nil
    }
  }

  func folderNameTitle(for request: FolderNameRequest) -> String {
    request.type == .folder
      ? "create_playlist_title".localized
      : "bound_books_create_alert_title".localized
  }
}
