Pod::Spec.new do |s|
  s.name             = 'whixp_transport'
  s.version          = '3.1.0'
  s.summary          = 'Native transport for Whixp (Rust).'
  s.description      = 'FFI library for TLS, polling, retry, stanza framing. DNS stays in Dart.'
  s.homepage         = 'https://github.com/vsevex/whixp'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Whixp' => 'https://github.com/vsevex/whixp' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.ios.deployment_target = '12.0'
  s.vendored_libraries = 'libwhixp_transport.a'
end
