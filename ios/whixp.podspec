Pod::Spec.new do |s|
  s.name             = 'whixp'
  s.version          = '3.3.0'
  s.summary          = 'Whixp XMPP client — native (Rust) transport for TLS, WebSocket, stanza framing.'
  s.description      = 'FFI library for TLS, polling, retry, stanza framing. DNS stays in Dart.'
  s.homepage         = 'https://github.com/vsevex/whixp'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Whixp' => 'https://github.com/vsevex/whixp' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.ios.deployment_target = '12.0'
  # XCFramework provides correct slice for device and simulator (fixes "symbol not found" on simulator).
  # Build with: make ios-xcframework
  if File.directory?(File.join(__dir__, 'WhixpTransport.xcframework'))
    s.vendored_frameworks = 'WhixpTransport.xcframework'
  else
    s.vendored_libraries = 'libwhixp_transport.a'
  end
end
