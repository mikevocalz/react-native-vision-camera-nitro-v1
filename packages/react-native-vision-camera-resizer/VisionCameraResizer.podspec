require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

# React Native CLI 20 still requires a podspec to discover iOS dependencies.
# Native sources, the Metal shader bundle and dependencies are built through Package.swift (Nitro V1).
Pod::Spec.new do |s|
  s.name         = "VisionCameraResizer"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]
  s.source       = { :git => "https://github.com/margelo/react-native-vision-camera.git", :tag => "v#{s.version}" }
  s.ios.deployment_target = "16.0"
  s.visionos.deployment_target = "1.0"
end
