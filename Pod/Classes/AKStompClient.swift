//
//  AKStompClient.swift
//
//  Created by Alexander Köhn
//

import UIKit
import SocketRocket

struct StompCommands {
    static let commandConnect = "CONNECT"
    static let commandSend = "SEND"
    static let commandSubscribe = "SUBSCRIBE"
    static let commandUnsubscribe = "UNSUBSCRIBE"
    static let commandBegin = "BEGIN"
    static let commandCommit = "COMMIT"
    static let commandAbort = "ABORT"
    static let commandAck = "ACK"
    static let commandDisconnect = "DISCONNECT"
    static let commandPing = "\n"
    
    static let controlChar = String(format: "%C", arguments: [0x00])
    
    static let ackClient = "client"
    static let ackAuto = "auto"
    
    static let commandHeaderReceipt = "receipt"
    static let commandHeaderDestination = "destination"
    static let commandHeaderDestinationId = "id"
    static let commandHeaderContentLength = "content-length"
    static let commandHeaderContentType = "content-type"
    static let commandHeaderAck = "ack"
    static let commandHeaderTransaction = "transaction"
    static let commandHeaderMessageId = "message-id"
    static let commandHeaderSubscription = "subscription"
    static let commandHeaderDisconnected = "disconnected"
    static let commandHeaderHeartBeat = "heart-beat"
    static let commandHeaderAcceptVersion = "accept-version"

    static let responseHeaderSession = "session"
    static let responseHeaderReceiptId = "receipt-id"
    static let responseHeaderErrorMessage = "message"
    
    static let responseFrameConnected = "CONNECTED"
    static let responseFrameMessage = "MESSAGE"
    static let responseFrameReceipt = "RECEIPT"
    static let responseFrameError = "ERROR"
}

public enum AKStompAckMode {
    case AutoMode
    case ClientMode
}

public protocol AKStompClientDelegate {
    
    func stompClient(client: AKStompClient!, didReceiveMessageWithJSONBody jsonBody: AnyObject?, withHeader header:[String:String]?, withDestination destination: String)
    
    func stompClientDidDisconnect(client: AKStompClient!)
    func stompClientWillDisconnect(client: AKStompClient!, withError error: NSError)
    func stompClientDidConnect(client: AKStompClient!)
    func serverDidSendReceipt(client: AKStompClient!, withReceiptId receiptId: String)
    func serverDidSendError(client: AKStompClient!, withErrorMessage description: String, detailedErrorMessage message: String?)
    func serverDidSendPing()
}

public class AKStompClient: NSObject, SRWebSocketDelegate {
    var socket: SRWebSocket?
    var sessionId: String?
    var delegate: AKStompClientDelegate?
    var connectionHeaders: [String: String]?
    var certificateCheckEnabled = true
    
    private var urlRequest: NSURLRequest?
    
    public func sendJSONForDict(dict: AnyObject, toDestination destination: String) {
        do {
            let theJSONData = try NSJSONSerialization.dataWithJSONObject(dict, options: NSJSONWritingOptions())
            let theJSONText = String(data: theJSONData, encoding: NSUTF8StringEncoding)
            //print(theJSONText!)
            let header = [StompCommands.commandHeaderContentType:"application/json;charset=UTF-8"]
            sendMessage(theJSONText!, toDestination: destination, withHeaders: header, withReceipt: nil)
        } catch {
            print("error serializing JSON: \(error)")
        }
    }
    
    public func openSocketWithURLRequest(request: NSURLRequest, delegate: AKStompClientDelegate) {
        self.delegate = delegate
        self.urlRequest = request
        
        openSocket()
    }
    
    public func openSocketWithURLRequest(request: NSURLRequest, delegate: AKStompClientDelegate, connectionHeaders: [String: String]?) {
        self.connectionHeaders = connectionHeaders
        openSocketWithURLRequest(request, delegate: delegate)
    }
    
    private func openSocket() {
        if socket == nil || socket?.readyState == .CLOSED {
            if certificateCheckEnabled == true {
                self.socket = SRWebSocket(URLRequest: urlRequest)
            } else {
                self.socket = SRWebSocket(URLRequest: urlRequest, protocols: [], allowsUntrustedSSLCertificates: true)
            }

            socket!.delegate = self
            socket!.open()
        }
    }
    
    private func connect() {
        if socket?.readyState == .OPEN {
            // at the moment only anonymous logins
            self.sendFrame(StompCommands.commandConnect, header: connectionHeaders, body: nil)
        } else {
            self.openSocket()
        }
    }
    
    public func webSocket(webSocket: SRWebSocket!, didReceiveMessage message: AnyObject!) {
//        print("didReceiveMessage")
        
        func processString(string: String) {
            var contents = string.componentsSeparatedByString("\n")
            if contents.first == "" {
                contents.removeFirst()
            }
            
            if let command = contents.first {
                var headers = [String: String]()
                var body = ""
                var hasHeaders  = false
                
                contents.removeFirst()
                for line in contents {
                    if hasHeaders == true {
                        body += line
                    } else {
                        if line == "" {
                            hasHeaders = true
                        } else {
                            let parts = line.componentsSeparatedByString(":")
                            if let key = parts.first {
                                headers[key] = parts.last
                            }
                        }
                    }
                }
                
                //remove garbage from body
                if body.hasSuffix("\0") {
                    body = body.stringByReplacingOccurrencesOfString("\0", withString: "")
                }
                
                receiveFrame(command, headers: headers, body: body)
            }
        }
        
        if let strData = message as? NSData {
            if let msg = String(data: strData, encoding: NSUTF8StringEncoding) {
                processString(msg)
            }
        } else if let str = message as? String {
            processString(str)
        }
    }
    
    public func webSocketDidOpen(webSocket: SRWebSocket!) {
        print("webSocketDidOpen")
        connect()
    }
    
    public func webSocket(webSocket: SRWebSocket!, didFailWithError error: NSError!) {
        print("didFailWithError: \(error)")
        
        if let delegate = delegate {
            dispatch_async(dispatch_get_main_queue(),{
                delegate.serverDidSendError(self, withErrorMessage: error.domain, detailedErrorMessage: error.description)
            })
        }
    }
    
    public func webSocket(webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
        print("didCloseWithCode \(code), reason: \(reason)")
        if let delegate = delegate {
            dispatch_async(dispatch_get_main_queue(),{
                delegate.stompClientDidDisconnect(self)
            })
        }
    }
    
    public func webSocket(webSocket: SRWebSocket!, didReceivePong pongPayload: NSData!) {
        print("didReceivePong")
    }
    
    private func sendFrame(command: String?, header: [String: String]?, body: AnyObject?) {
        if socket?.readyState == .OPEN {
            var frameString = ""
            if command != nil {
                frameString = command! + "\n"
            }
            
            if let header = header {
                for (key, value) in header {
                    frameString += key
                    frameString += ":"
                    frameString += value
                    frameString += "\n"
                }
            }
            
            if let body = body as? String {
                frameString += "\n"
                frameString += body
            } else if let _ = body as? NSData {
                //ak, 20151015: do we need to implemenet this?
            }
            
            if body == nil {
                frameString += "\n"
            }
            
            frameString += StompCommands.controlChar
            
            if socket?.readyState == .OPEN {
                socket?.send(frameString)
            } else {
                print("no socket connection")
                if let delegate = delegate {
                    dispatch_async(dispatch_get_main_queue(),{
                        delegate.stompClientDidDisconnect(self)
                    })
                }
            }
        }
    }
    
    private func destinationFromHeader(header: [String: String]) -> String {
        for (key, _) in header {
            if key == "destination" {
                let destination = header[key]!
                return destination
            }
        }
        return ""
    }
    
    private func dictForJSONString(jsonStr: String?) -> AnyObject? {
        if let jsonStr = jsonStr {
            do {
                if let data = jsonStr.dataUsingEncoding(NSUTF8StringEncoding) {
                    let json = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
                    return json
                }
            } catch {
                print("error serializing JSON: \(error)")
            }
        }
        return nil
    }
    
    private func receiveFrame(command: String, headers: [String: String], body: String?) {
        if command == StompCommands.responseFrameConnected {
            // Connected
            if let sessId = headers[StompCommands.responseHeaderSession] {
                sessionId = sessId
            }
            
            if let delegate = delegate {
                dispatch_async(dispatch_get_main_queue(),{
                    delegate.stompClientDidConnect(self)
                })
            }
        } else if command == StompCommands.responseFrameMessage {
            // Resonse

            if headers["content-type"]?.lowercaseString.rangeOfString("application/json") != nil {
                if let delegate = delegate {
                    dispatch_async(dispatch_get_main_queue(),{
                        delegate.stompClient(self, didReceiveMessageWithJSONBody: self.dictForJSONString(body), withHeader: headers, withDestination: self.destinationFromHeader(headers))
                    })
                }
            } else {
                // TODO: send binary data back
            }
        } else if command == StompCommands.responseFrameReceipt {
            // Receipt
            if let delegate = delegate {
                if let receiptId = headers[StompCommands.responseHeaderReceiptId] {
                    dispatch_async(dispatch_get_main_queue(),{
                        delegate.serverDidSendReceipt(self, withReceiptId: receiptId)
                    })
                }
            }
        } else if command.characters.count == 0 {
            // Pong from the server
            socket?.send(StompCommands.commandPing)
            
            if let delegate = delegate {
                dispatch_async(dispatch_get_main_queue(),{
                    delegate.serverDidSendPing()
                })
            }
        } else if command == StompCommands.responseFrameError {
            // Error
            if let delegate = delegate {
                if let msg = headers[StompCommands.responseHeaderErrorMessage] {
                    dispatch_async(dispatch_get_main_queue(),{
                        delegate.serverDidSendError(self, withErrorMessage: msg, detailedErrorMessage: body)
                    })
                }
            }
        }
    }
    
    public func sendMessage(message: String, toDestination destination: String, withHeaders headers: [String: String]?, withReceipt receipt: String?) {
        var headersToSend = [String: String]()
        if let headers = headers {
            headersToSend = headers
        }
        
        // Setting up the receipt.
        if let receipt = receipt {
            headersToSend[StompCommands.commandHeaderReceipt] = receipt
        }
        
        headersToSend[StompCommands.commandHeaderDestination] = destination
        
        // Setting up the content length.
        let contentLength = message.utf8.count
        headersToSend[StompCommands.commandHeaderContentLength] = "\(contentLength)"
        
        // Setting up content type as plain text.
        if headersToSend[StompCommands.commandHeaderContentType] == nil {
            headersToSend[StompCommands.commandHeaderContentType] = "text/plain"
        }
        
        sendFrame(StompCommands.commandSend, header: headersToSend, body: message)
    }
    
    public func subscribeToDestination(destination: String) {
        subscribeToDestination(destination, withAck: .AutoMode)
    }
    
    public func subscribeToDestination(destination: String, withAck ackMode: AKStompAckMode) {
        var ack = ""
        switch ackMode {
        case AKStompAckMode.ClientMode:
            ack = StompCommands.ackClient
            break
        default:
            ack = StompCommands.ackAuto
            break
        }
        
        let headers = [StompCommands.commandHeaderDestination: destination, StompCommands.commandHeaderAck: ack, StompCommands.commandHeaderDestinationId: ""]
        
        self.sendFrame(StompCommands.commandSubscribe, header: headers, body: nil)
    }
    
    public func subscribeToDestination(destination: String, withHeader header: [String: String]) {
        var headerToSend = header
        headerToSend[StompCommands.commandHeaderDestination] = destination
        sendFrame(StompCommands.commandSubscribe, header: headerToSend, body: nil)
    }
    
    public func unsubscribeFromDestination(destination: String) {
        var headerToSend = [String: String]()
        headerToSend[StompCommands.commandHeaderDestinationId] = destination
        sendFrame(StompCommands.commandUnsubscribe, header: headerToSend, body: nil)
    }

    public func begin(transactionId: String) {
        var headerToSend = [String: String]()
        headerToSend[StompCommands.commandHeaderTransaction] = transactionId
        sendFrame(StompCommands.commandBegin, header: headerToSend, body: nil)
    }

    public func commit(transactionId: String) {
        var headerToSend = [String: String]()
        headerToSend[StompCommands.commandHeaderTransaction] = transactionId
        sendFrame(StompCommands.commandCommit, header: headerToSend, body: nil)
    }
    
    public func abort(transactionId: String) {
        var headerToSend = [String: String]()
        headerToSend[StompCommands.commandHeaderTransaction] = transactionId
        sendFrame(StompCommands.commandAbort, header: headerToSend, body: nil)
    }
    
    public func ack(messageId: String) {
        var headerToSend = [String: String]()
        headerToSend[StompCommands.commandHeaderMessageId] = messageId
        sendFrame(StompCommands.commandAck, header: headerToSend, body: nil)
    }

    public func ack(messageId: String, withSubscription subscription: String) {
        var headerToSend = [String: String]()
        headerToSend[StompCommands.commandHeaderMessageId] = messageId
        headerToSend[StompCommands.commandHeaderSubscription] = subscription
        sendFrame(StompCommands.commandAck, header: headerToSend, body: nil)
    }
    
    public func disconnect() {
        var headerToSend = [String: String]()
        headerToSend[StompCommands.commandDisconnect] = String(Int(NSDate().timeIntervalSince1970))
        sendFrame(StompCommands.commandDisconnect, header: headerToSend, body: nil)
    }
}
