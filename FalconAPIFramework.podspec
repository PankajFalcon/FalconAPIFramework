Pod::Spec.new do |s|
  s.name             = 'FalconAPIFramework'
  s.version          = '0.1.0'
  s.summary          = 'FalconAPIFramework provides API helpers for Swift projects.'
  s.description      = <<-DESC
    FalconAPIFramework is a lightweight Swift framework designed to simplify API networking 
    using async/await and actor-based services.
  DESC
  s.homepage         = 'https://github.com/PankajFalcon/FalconAPIFramework'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Pankaj' => 'pankaj@falconsystem.com' }

  s.source           = {
    :git => 'https://github.com/PankajFalcon/FalconAPIFramework.git',
    :tag => s.version.to_s
  }

  s.ios.deployment_target = '13.0'
  s.source_files     = 'Sources/FalconAPIFramework/**/*.{swift,h,m}'
  s.swift_version    = '5.0'
end
