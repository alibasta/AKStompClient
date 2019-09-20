# AKStompClient

[![CI Status](http://img.shields.io/travis/Alexander Köhn/AKStompClient.svg?style=flat)](https://travis-ci.org/Alexander Köhn/AKStompClient)
[![Version](https://img.shields.io/cocoapods/v/AKStompClient.svg?style=flat)](http://cocoapods.org/pods/AKStompClient)
[![License](https://img.shields.io/cocoapods/l/AKStompClient.svg?style=flat)](http://cocoapods.org/pods/AKStompClient)
[![Platform](https://img.shields.io/cocoapods/p/AKStompClient.svg?style=flat)](http://cocoapods.org/pods/AKStompClient)

## About

AKStompClient is a STOMP Websocket client written in Swift using SocketRocket to communicate over WebSocket. At the moment I only support sending and receiving JSON data.

## Usage

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

AKStompClient is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "AKStompClient"
```

## How to use

**Connect to the server:**

Use the *AKStompClientDelegate* delegate in your class.

```swift
socketClient = AKStompClient()

socketClient!.openSocketWithURLRequest(NSURLRequest(URL: serverURL()), delegate: self, connectionHeaders: ["clientType": "REMOTE", "authkey": "n/a", "qrCode": qrCode])
```

**Delegate callbacks**

The most interesting delegate callbacks are the *func stompClientDidConnect(client: AKStompClient!)* and the *func stompClient(client: AKStompClient!, didReceiveMessageWithJSONBody jsonBody: AnyObject?, withHeader header:[String:String]?, withDestination destination: String)* callbacks. 

In the *func stompClientDidConnect(client: AKStompClient!)* we subscribe to our destination(s): 

```swift
func stompClientDidConnect(client: AKStompClient!) {
    client.subscribeToDestination("/topic/helloworld")
}
```

In the *func stompClient(client: AKStompClient!, didReceiveMessageWithJSONBody jsonBody: AnyObject?, withHeader header:[String:String]?, withDestination destination: String)* we are waiting for messages:

```swift
func stompClient(client: AKStompClient!, didReceiveMessageWithJSONBody jsonBody: AnyObject?, withHeader header:[String:String]?, withDestination destination: String) {
    if destionation == "the-destination-im-waiting-for" {
        if let jsonBody = jsonBody as? NSDictionary {
            print("\(jsonBody)")
        }
    }
}
```

## Author

Alexander Köhn, ak@nuuk.de

## License

AKStompClient is available under the MIT license. See the LICENSE file for more info.
