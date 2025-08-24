//
//  SimpleLibraryItem+SwiftUI.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 23/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

extension SimpleLibraryItem: @retroactive Transferable {
  public static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .url) { item in
      SentTransferredFile(item.fileURL)
    }
  }
}
