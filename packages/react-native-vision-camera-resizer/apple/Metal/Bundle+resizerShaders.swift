//
//  Bundle+resizerShaders.swift
//  VisionCamera
//

import Foundation

extension Bundle {
  /// The bundle that holds the compiled `ResizerKernels.metal` library.
  ///
  /// SwiftPM compiles the shader into the target's resource bundle (`Bundle.module`).
  /// CocoaPods compiles it into `VisionCameraResizer.bundle` (`s.resource_bundles`), which
  /// it copies next to the code that links this pod.
  static var resizerShaders: Bundle? {
    #if SWIFT_PACKAGE
      return Bundle.module
    #else
      let codeBundle = Bundle(for: HybridResizerFactory.self)
      for candidate in [codeBundle, Bundle.main] {
        if let url = candidate.url(forResource: "VisionCameraResizer", withExtension: "bundle"),
          let bundle = Bundle(url: url)
        {
          return bundle
        }
      }
      return nil
    #endif
  }
}
