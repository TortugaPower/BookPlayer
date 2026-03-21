//
//  ExternalSourceSyncOperation.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 20/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

class ExternalSourceSyncOperation: Operation {
    enum State: String {
        case ready, executing, finished
        fileprivate var keyPath: String { return "is\(rawValue.capitalized)" }
    }
    
    var state = State.ready {
        willSet {
            willChangeValue(forKey: newValue.keyPath)
            willChangeValue(forKey: state.keyPath)
        }
        didSet {
            didChangeValue(forKey: oldValue.keyPath)
            didChangeValue(forKey: state.keyPath)
        }
    }
    
    override var isReady: Bool { super.isReady && state == .ready }
    override var isExecuting: Bool { state == .executing }
    override var isFinished: Bool { state == .finished }
    override var isAsynchronous: Bool { true }
    
    override func start() {
        guard !isCancelled else {
            state = .finished
            return
        }
        main()
        state = .executing
    }
    
    // Subclasses must call this when their async work is totally done
    func finish() {
        state = .finished
    }
}
