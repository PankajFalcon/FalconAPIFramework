Pod::Spec.new do |spec|
  spec.name         = "APIFramework"
  spec.version      = "0.0.1"
  spec.summary      = "A modern Swift framework to simplify API requests using async/await."

  spec.description  = <<-DESC
APIFramework is a lightweight Swift framework for handling network calls with async/await. 
It offers a clean, reusable architecture using the latest Swift concurrency features.
  DESC

  spec.homepage     = "https://github.com/PankajFalcon/APIFramework"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "Your Name" => "pankaj@falconsystem.com" }
  spec.source       = { :git => "https://github.com/PankajFalcon/APIFramework.git", :tag => "#{spec.version}" }

  spec.platform     = :ios, "15.0"
  spec.swift_versions = ["5.5"]
  spec.source_files  = "Sources/APIFramework/**/*.{swift}"
end
