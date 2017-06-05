
Pod::Spec.new do |s|

  s.name        = "SecureSocket"
  s.module_name = s.name
  s.version     = "1.0.0"
  s.summary     = "SecureSocket is a generic low level socket framework written in Swift."
  s.homepage    = "https://github.com/Meniny/SecureSocket"
  s.license     = 'MIT'
  s.author      = {
    "Meniny" => "Meniny@qq.com"
  }
  s.source      = {
    :git => "https://github.com/Meniny/SecureSocket.git",
    :tag => s.version.to_s
  }
  s.social_media_url = 'http://meniny.cn/'

  s.requires_arc = true
  s.osx.deployment_target = "10.11"
  s.ios.deployment_target = "10.0"
  s.watchos.deployment_target = "2.0"
  s.tvos.deployment_target = "9.0"

  s.source_files = "Sources/*.swift"

  s.pod_target_xcconfig = {
    'SWIFT_VERSION' => '3.1.1'
  }
end
