//
//  ViewController.swift
//  ClientDemo
//
//  Created by Meniny on 2017-06-05.
//  Copyright © 2017年 Meniny. All rights reserved.
//

import Cocoa
import SecureSocket
import Dispatch

class ViewController: NSViewController {
    
    @IBOutlet weak var messageLabel: NSTextField!
    @IBOutlet weak var sendButton: NSButton!
    
    @IBOutlet weak var serverButton: NSButton!
    @IBOutlet weak var clientButton: NSButton!
    
    let port: Int32 = 1337
    let host: String = "127.0.0.1"
    let type: Socket.SocketType = .stream
    let proto: Socket.SocketProtocol = .tcp
    let family: Socket.ProtocolFamily = .inet
    
    let quit = "QUIT"

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        if kAppType == .client {
            self.startClient(self.clientButton)
        } else {
            self.startServer(self.serverButton)
        }
    }
    
    // MARK: - Common
    
    func restore(_ isClient: Bool = false) {
        DispatchQueue.main.async { [unowned self] in
            self.show("----------------------")
            if isClient {
                self.serverButton.isEnabled = true
                self.clientButton.isEnabled = true
                self.sendButton.isEnabled = false
                self.sendButton.title = "Send"                
            }
        }
    }
    
    func show(_ text: String) {
        DispatchQueue.main.async { [unowned self] in
            self.messageLabel.stringValue = self.messageLabel.stringValue + "\n" + text
        }
    }
    
    // MARK: - Server
    
    @IBAction func startServer(_ sender: NSButton) {
        self.title = "Server"
        self.serverButton.isEnabled = false
        self.clientButton.isEnabled = false
        
        DispatchQueue.global(qos: .userInteractive).async { [unowned self] in
            do {
                try self.serverHelper()
                
            } catch let error {
                
                self.restore()
                
                guard let socketError = error as? Socket.Error else {
                    
                    self.show("Unexpected error...")
                    return
                }
                
                self.show("launchServerHelper Error reported:\n \(socketError.description)")
            }
        }
    }
    
    func serverHelper() throws {
        
        var listenSocket: Socket? = nil
        
        do {
            
            try listenSocket = Socket.create(family: self.family)
            
            guard let listener = listenSocket else {
                
                self.show("Unable to unwrap socket...")
                
                return
            }
            
            // Setting up TCP...
            try listener.listen(on: Int(self.port))
            self.show("Listening on port: \(port)")
            
            while true {
                self.serverAcceptClient(listener)
            }
            
        } catch let error {
            
            guard let socketError = error as? Socket.Error else {
                
                self.show("Unexpected error...")
                
                return
            }
            
            // This error is expected when we're shutting it down...
            if socketError.errorCode == Int32(Socket.SOCKET_ERR_WRITE_FAILED) {
                return
            }
            self.show("serverHelper Error reported: \(socketError.description)")
            
        }
    }
    
    func serverAcceptClient(_ server: Socket) {
        var socket: Socket
        do {
            
            socket = try server.acceptClientConnection()
            
            self.show("Accepted : \(socket.remoteHostname): \(socket.remotePort), Secure? \(socket.signature!.isSecure)")
            
            try socket.write(from: "Hello, type 'QUIT' to end session\n")
            
            var keepRunning: Bool = true
            var bytesRead = 0
            repeat {
                
                var readData = Data()
                bytesRead = try socket.read(into: &readData)
                
                if bytesRead > 0 {
                    
                    guard let response = NSString(data: readData, encoding: String.Encoding.utf8.rawValue) else {
                        
                        self.show("Error decoding response...")
                        readData.count = 0
                        break
                    }
                    
                    self.show("Received [\(socket.remoteHostname):\(socket.remotePort)]: \(response) ")
                    
                    if response.hasPrefix(self.quit) {
                        keepRunning = false
                        socket.close()
                        self.show("Server Closed")
                        self.restore()
                    } else {
                        let reply = "Server response: \n\(response)\n"
                        try socket.write(from: reply)
                    }
                }
                
                if bytesRead == 0 {
                    //                    break
                }
                
            } while keepRunning
        } catch let error {
            self.restore()
            
            guard let socketError = error as? Socket.Error else {
                self.show("Unexpected error...")
                return
            }
            
            // This error is expected when we're shutting it down...
            if socketError.errorCode == Int32(Socket.SOCKET_ERR_WRITE_FAILED) {
                return
            }
            
            self.show("Error reported: \(socketError.description)")
        }
    }
    
    // MARK: - Client
    
    @IBAction func startClient(_ sender: NSButton) {
        self.title = "Client"
        self.serverButton.isEnabled = false
        self.clientButton.isEnabled = false
        self.sendButton.isEnabled = true
        
        DispatchQueue.global(qos: .userInteractive).async { [unowned self] in
            self.clientHelper()
        }
    }
    
    var client: Socket? = nil

    func clientHelper() {
        
        do {
            // Create a signature...
            let signature = try Socket.Signature(protocolFamily: self.family,
                                                 socketType: self.type,
                                                 proto: self.proto,
                                                 hostname: self.host,
                                                 port: self.port)
            
            // Create a connected socket using the signature...
            self.client = try Socket.create(connectedUsing: signature!)
            if self.client != nil {
                self.show("Client launched")
            } else {
                self.show("Create client failed")
                self.closeClient()
            }
            
        } catch let error {
            self.closeClient()
            
            // See if it's a socket error or something else...
            guard let socketError = error as? Socket.Error else {
                
                self.show("clientHelper Unexpected error...")
                return
            }
            
            self.show("clientHelper Error reported: \(socketError.description)")
        }
    }
    
    // MARK: -
    
    var messages: [String] = [
        "Say Hello!",
        "What's up",
        "How's going",
        "I like your dress",
        "Nice shoot",
        "Time to go",
    ]
    
    var messageIndex = 0
    
    @IBAction func sendMessage(_ sender: NSButton) {
        if let c = self.client {
            if messageIndex < messages.count {
                self.client(c, sendMessage: messages[messageIndex])
                messageIndex += 1
                if messageIndex == messages.count {
                    self.sendButton.title = self.quit
                }
            } else if messageIndex == messages.count {
                messageIndex = 0
                self.client(c, sendMessage: self.quit)
                self.closeClient()
            } else {
                messageIndex = 0
            }
        }
    }
    
    func client(_ socket: Socket, sendMessage message: String) {
        do {
            try socket.write(from: message)
            self.show("Sending: " + message)
            
        } catch let error {
            self.show("Error reported: \(error.localizedDescription)")
        }
    }
    
    func closeClient() {
        if let c = self.client {
            self.show("Client closed")
            c.close()
        }
        self.restore(true)
    }
    
}





