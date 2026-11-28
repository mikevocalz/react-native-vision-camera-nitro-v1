require "json"
require_relative "nitro_v1_cocoapods"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

# iOS builds through Package.swift under SwiftPM and through this pod under
# CocoaPods (Expo). nitro_v1_cocoapods.rb mirrors the Package.swift targets.
Pod::Spec.new do |s|
  s.name         = "VisionCameraResizer"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]
  s.source       = { :git => "https://github.com/mikevocalz/react-native-vision-camera-nitro-v1.git", :tag => "#{s.version}" }

  s.ios.deployment_target = "16.0"
  s.osx.deployment_target = "13.0"
  s.tvos.deployment_target = "16.0"
  s.visionos.deployment_target = "1.0"

  NitroV1CocoaPods.configure(
    s,
    package_dir: __dir__,
    module_name: "VisionCameraResizer",
    nitro_dependencies: ["react-native-vision-camera"],
  )
  # Package.swift processes shaders/ResizerKernels.metal into the package's
  # resource bundle; MetalResizerShaderLibrary loads it from the bundle of the
  # same name under CocoaPods.
  s.resource_bundles = { "VisionCameraResizer" => ["shaders/ResizerKernels.metal"] }
  s.frameworks = "Metal", "CoreVideo", "AVFoundation"
end
