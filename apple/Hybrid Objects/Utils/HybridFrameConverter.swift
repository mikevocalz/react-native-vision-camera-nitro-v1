///
/// HybridFrameConverter.swift
/// VisionCamera
/// Copyright © 2025 Marc Rousavy @ Margelo
///

import AVFoundation
import Foundation
import NitroImage
import NitroModules

// `@unchecked Sendable`: V1 `.parallel` closures are `@Sendable`; it has no stored state.
final class HybridFrameConverter: HybridFrameConverterSpec, @unchecked Sendable {
  func convertFrameToImage(frame: any HybridFrameSpec) throws -> any HybridImageSpec {
    guard let frame = frame as? any NativeFrame else {
      throw RuntimeError("The given `Frame` is not of type `NativeFrame`!")
    }
    guard let sampleBuffer = frame.sampleBuffer else {
      throw RuntimeError("The given `Frame` has already been disposed!")
    }
    let uiOrientation = frame.metadata.uiImageOrientation
    let uiImage = try sampleBuffer.toUIImage(orientation: uiOrientation)
    return try HybridUIImage(uiImage: uiImage)
  }

  func convertFrameToImageAsync(frame: any HybridFrameSpec) throws -> any Promise<any HybridImageSpec> {
    // JS keeps `frame` alive until the Promise settles; the conversion only reads it.
    nonisolated(unsafe) let frame = frame
    return .parallel {
      return try self.convertFrameToImage(frame: frame)
    }
  }

  func convertDepthToImage(depth: any HybridDepthSpec) throws -> any HybridImageSpec {
    guard let depth = depth as? any NativeDepth else {
      throw RuntimeError("The given `Depth` is not of type `NativeDepth`!")
    }
    guard let depthData = depth.depthData else {
      throw RuntimeError("Cannot convert an already disposed Depth to an Image!")
    }
    let uiOrientation = depth.metadata.uiImageOrientation
    let uiImage = try depthData.toUIImage(orientation: uiOrientation)
    return try HybridUIImage(uiImage: uiImage)
  }

  func convertDepthToImageAsync(depth: any HybridDepthSpec) throws -> any Promise<any HybridImageSpec> {
    // JS keeps `depth` alive until the Promise settles; the conversion only reads it.
    nonisolated(unsafe) let depth = depth
    return .parallel {
      return try self.convertDepthToImage(depth: depth)
    }
  }
}
