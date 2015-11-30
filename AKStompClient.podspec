Pod::Spec.new do |s|
  s.name             = "AKStompClient"
  s.version          = "0.1.0"
  s.summary          = "STOMP Websocket client"
  s.description      = "A STOMP Websocket client written in Swift using SocketRocket to communicate over WebSocket. At the moment I only support sending and receiving JSON data."

  s.homepage         = "https://github.com/alibasta/AKStompClient"
  s.license          = 'MIT'
  s.author           = { "Alexander Köhn" => "ak@newscope.com" }
  s.source           = { :git => "https://github.com/alibasta/AKStompClient.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/alibasta'

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.dependency 'SocketRocket', '~> 0.4'
end
