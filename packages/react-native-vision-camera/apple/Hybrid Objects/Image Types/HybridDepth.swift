//
//  HybridDepth.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 29.10.25.
//

import AVFoundation
import Foundation
import NitroModules

// `@unchecked Sendable`: V1 `.async` closures are `sending`; the `*Async` methods read `depthData` off the JS thread. `dispose()` racing one of them is the same race VisionCamera 5.2.3 has; JS owns the lifetime.
final class HybridDepth: HybridDepthSpec, NativeDepth, LazyLockableBuffer, @unchecked Sendable {
  var depthData: AVDepthData?
  let metadata: MediaSampleMetadata
  var isLocked: Bool = false
  var pixelBuffer: CVPixelBuffer? {
    return depthData?.depthDataMap
  }

  init(
    depthData: AVDepthData,
    metadata: MediaSampleMetadata
  ) throws {
    self.depthData = depthData
    self.metadata = metadata
    try super.init()
  }

  func dispose() {
    unlockBuffer()
    depthData = nil
  }

  var memorySize: Int {
    return pixelBuffer?.memorySize ?? 0
  }

  var isValid: Bool {
    return depthData != nil
  }

  var width: Double {
    guard let pixelBuffer else {
      return 0
    }
    return Double(CVPixelBufferGetWidth(pixelBuffer))
  }
  var height: Double {
    guard let pixelBuffer else {
      return 0
    }
    return Double(CVPixelBufferGetHeight(pixelBuffer))
  }

  var bytesPerRow: Double {
    guard let pixelBuffer else {
      return 0
    }
    return Double(CVPixelBufferGetBytesPerRow(pixelBuffer))
  }

  var timestamp: Double {
    return metadata.timestamp.seconds
  }
  var orientation: CameraOrientation {
    return metadata.orientation
  }
  var isMirrored: Bool {
    return metadata.isMirrored
  }

  var pixelFormat: DepthPixelFormat {
    guard let depthData else {
      return .unknown
    }
    return DepthPixelFormat(osType: depthData.depthDataType)
  }

  var isDepthDataFiltered: Bool {
    return depthData?.isDepthDataFiltered ?? false
  }

  var depthDataAccuracy: DepthDataAccuracy {
    guard let depthData else {
      return .unknown
    }
    return DepthDataAccuracy(av: depthData.depthDataAccuracy)
  }

  var depthDataQuality: DepthDataQuality {
    guard let depthData else {
      return .unknown
    }
    return DepthDataQuality(av: depthData.depthDataQuality)
  }

  var availableDepthPixelFormats: [DepthPixelFormat] {
    guard let depthData else {
      return []
    }
    return depthData.availableDepthDataTypes.map { DepthPixelFormat(osType: $0) }
  }

  var cameraCalibrationData: (any HybridCameraCalibrationDataSpec)? {
    guard let depthData,
      let calibrationData = depthData.cameraCalibrationData
    else {
      return nil
    }
    // The Hybrid init only throws from `HybridObject` base setup, which cannot fail, and a getter cannot throw.
    return try! HybridCameraCalibrationData(calibrationData: calibrationData)
  }

  func rotate(orientation: CameraOrientation, isMirrored: Bool) throws -> any HybridDepthSpec {
    guard let depthData else {
      throw RuntimeError("Tried to rotate an already disposed Depth!")
    }
    let cgOrientation = orientation.toCGOrientation(isMirrored: isMirrored)
    let rotated = depthData.applyingExifOrientation(cgOrientation)
    return try HybridDepth(
      depthData: rotated,
      metadata: metadata)
  }

  func rotateAsync(orientation: CameraOrientation, isMirrored: Bool) throws -> any Promise<
    any HybridDepthSpec
  > {
    return .async {
      return try self.rotate(orientation: orientation, isMirrored: isMirrored)
    }
  }

  func convert(pixelFormat: DepthPixelFormat) throws -> any HybridDepthSpec {
    guard let depthData else {
      throw RuntimeError("Tried to convert an already disposed Depth!")
    }
    let osFormat = try pixelFormat.toCVPixelFormatType()
    let converted = depthData.converting(toDepthDataType: osFormat)
    return try HybridDepth(
      depthData: converted,
      metadata: metadata)
  }

  func convertAsync(pixelFormat: DepthPixelFormat) throws -> any Promise<any HybridDepthSpec> {
    return .async {
      return try self.convert(pixelFormat: pixelFormat)
    }
  }

  func convertCameraPointToDepthPoint(cameraPoint: Point) throws -> Point {
    guard let pixelBuffer else {
      throw RuntimeError("This Depth has already been disposed!")
    }
    let matrix = FrameCoordinateSystemConverter.getCameraToFrameMatrix(
      pixelBuffer: pixelBuffer,
      orientation: orientation,
      isMirrored: isMirrored)
    return cameraPoint.applying(matrix)
  }

  func convertDepthPointToCameraPoint(depthPoint: Point) throws -> Point {
    guard let pixelBuffer else {
      throw RuntimeError("This Depth has already been disposed!")
    }
    let matrix = FrameCoordinateSystemConverter.getFrameToCameraMatrix(
      pixelBuffer: pixelBuffer,
      orientation: orientation,
      isMirrored: isMirrored)
    return depthPoint.applying(matrix)
  }

  func getDepthData() throws -> ArrayBuffer {
    guard let depthData else {
      throw RuntimeError("Cannot get an already disposed Depth Frame's data!")
    }
    try ensureBufferLocked()
    return try ArrayBuffer.fromPixelBuffer(depthData.depthDataMap)
  }

  func getNativeBuffer() throws -> NativeBuffer {
    guard let pixelBuffer else {
      throw RuntimeError("This Depth has already been disposed!")
    }
    return pixelBuffer.asNativeBuffer()
  }

  func toFrame() throws -> any HybridFrameSpec {
    guard let depthData else {
      throw RuntimeError("Cannot convert an already disposed Depth to a Frame!")
    }
    let format = try CMFormatDescription(imageBuffer: depthData.depthDataMap)
    let timing = CMSampleTimingInfo(
      duration: .zero,
      presentationTimeStamp: metadata.timestamp,
      decodeTimeStamp: .zero)
    let sampleBuffer = try CMSampleBuffer(
      imageBuffer: depthData.depthDataMap,
      formatDescription: format,
      sampleTiming: timing)
    return try HybridFrame(
      buffer: sampleBuffer,
      metadata: metadata)
  }
  func toFrameAsync() -> any Promise<any HybridFrameSpec> {
    return .async {
      return try self.toFrame()
    }
  }
}
