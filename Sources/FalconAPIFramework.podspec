Pod::Spec.new do |s|
  s.name             = 'FalconAPIFramework'
  s.version          = '0.1.0'
  s.summary          = 'Your awesome Swift CocoaPod.'
  s.description      = 'A longer description of your pod.'
  s.homepage         = 'https://github.com/PankajFalcon/FalconAPIFramework'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Your Name' => 'your@email.com' }
  s.source           = { :git => 'https://github.com/PankajFalcon/YourPodName.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.source_files = 'Sources/**/*'
  s.swift_version = '5.0'
end
