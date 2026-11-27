//
//  HybridResizerFactory.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 29.10.25.
//

import AVFoundation
import Metal
import NitroModules

final class HybridResizerFactory: HybridResizerFactorySpec {
  func isAvailable() -> Bool {
    return MTLCreateSystemDefaultDevice() != nil
  }

  func createResizer(options: ResizerOptions) throws -> any Promise<any HybridResizerSpec> {
    return .parallel {
      // Initialize Metal resizer pipeline off the JS Thread
      return try HybridResizer(options: options)
    }
  }
}
