//
//  SocketClient.swift
//  BookPlayer
//
//  Created by Yamil Nuñez Aguirre on 13/8/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation
import SocketIO

public protocol SocketClientProtocol {
	func connectSocket() throws
	func disconnectSocket() throws
}

public class SocketClient: SocketClientProtocol, BPLogger {

	var socket: SocketIOClient? = nil
	let manager: SocketManager?

	public init() {
		let serverURL: String = Bundle.main.configurationValue(for: .socketServerURL)
		print("server url \(serverURL)")
		self.manager = SocketManager(socketURL: URL(string: serverURL)!, config: [.log(false), .compress])
		self.socket = self.manager?.defaultSocket
		self.setupSocketEvents()
	}
	
	public func connectSocket() throws {
		self.socket?.connect()
		print("connectSocket")
	}
	
	public func disconnectSocket() throws {
		self.socket?.removeAllHandlers()
		self.socket?.disconnect()
	}
	
	
	func setupSocketEvents() {
		self.socket?.on(clientEvent: .connect) {data, ack in
			Self.logger.trace("[Socketclient] connected")
		}
//
//		socket?.on("drawing") { (data, ack) in
//				guard let dataInfo = data.first else { return }
//				if let response: SocketPosition = try? SocketParser.convert(data: dataInfo) {
//						let position = CGPoint.init(x: response.x, y: response.y)
//						self.delegate?.didReceive(point: position)
//				}
//		}
	}
}
