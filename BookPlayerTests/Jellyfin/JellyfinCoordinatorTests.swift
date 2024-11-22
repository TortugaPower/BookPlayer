//
//  JellyfinCoordinatorTests.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-22.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

@testable import BookPlayer
import BookPlayerKit
import XCTest

class JellyfinCoordinatorTests: XCTestCase {
  var sut: JellyfinCoordinator!
  var presentingController: MockNavigationController!
  
  override func setUp() {
    presentingController = MockNavigationController()
    
    let mockSingleFileDownloadService = SingleFileDownloadService(networkClient: NetworkClientMock(mockedResponse: Empty.value))
    let mockJellyfinConnectionService = JellyfinConnectionService(keychainService: KeychainServiceMock())
    sut = JellyfinCoordinator(flow: .pushFlow(navigationController: presentingController),
                              singleFileDownloadService: mockSingleFileDownloadService,
                              jellyfinConnectionService: mockJellyfinConnectionService)
    sut.start()
  }
  
  func testInitialState() {
    XCTAssertEqual(presentingController.horizontalStack.first, "UIHostingController<JellyfinConnectionView>")
  }
}
