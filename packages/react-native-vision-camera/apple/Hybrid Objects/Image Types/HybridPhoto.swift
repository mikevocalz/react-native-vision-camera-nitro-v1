//
//  HybridPhoto.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 29.10.25.
//

import AVFoundation
import UIKit
import Foundation
import NitroImage
import NitroModules

final class HybridPhoto: HybridPhotoSpec, NativePhoto {
  let photo: AVCapturePhoto
  let metadata: MediaSampleMetadata
  let containerFormat: PhotoContainerFormat

  init(
    photo: AVCapturePhoto,
    metadata: MediaSampleMetadata,
    containerFormat: PhotoContainerFormat
  ) throws {
    self.photo = photo
    self.metadata = metadata
    self.containerFormat = containerFormat
    try super.init()
  }

  var memorySize: Int {
    return photo.memorySize
  }

  // pragma MARK: Photo metadata

  var timestamp: Double {
    return photo.timestamp.seconds
  }
  var isMirrored: Bool {
    return metadata.isMirrored
  }
  var orientation: CameraOrientation {
    return metadata.orientation
  }

  var isRawPhoto: Bool {
    return photo.isRawPhoto
  }

  var depth: (any HybridDepthSpec)? {
    guard let depthData = photo.depthData else {
      return nil
    }
    // Hybrid inits only throw from `HybridObject` base setup, which cannot fail, and a getter cannot throw.
    return try? HybridDepth(
      depthData: depthData,
      metadata: metadata)
  }

  var size: CMVideoDimensions {
    if isRawPhoto {
      return photo.resolvedSettings.rawPhotoDimensions
    } else {
      return photo.resolvedSettings.photoDimensions
    }
  }
  var width: Double {
    return Double(size.width)
  }
  var height: Double {
    return Double(size.height)
  }

  var calibrationData: (any HybridCameraCalibrationDataSpec)? {
    guard let calibrationData = photo.cameraCalibrationData else {
      return nil
    }
    // Hybrid inits only throw from `HybridObject` base setup, which cannot fail, and a getter cannot throw.
    return try? HybridCameraCalibrationData(calibrationData: calibrationData)
  }

  // pragma MARK: Pixel Buffer access

  var hasPixelBuffer: Bool {
    return photo.pixelBuffer != nil
  }
  func getPixelBuffer() throws -> ArrayBuffer {
    guard let pixelBuffer = photo.pixelBuffer else {
      throw RuntimeError("This Photo does not contain a pixel buffer! "
          + "Check `photo.hasPixelBuffer` before calling `photo.getPixelBuffer()`")
    }
    return try ArrayBuffer.fromPixelBuffer(pixelBuffer)
  }

  // pragma MARK: File Data

  func getFileData() throws -> ArrayBuffer {
    guard let data = photo.fileDataRepresentation() else {
      throw RuntimeError("Failed to get photo's file data!")
    }
    return try ArrayBuffer.copy(data: data)
  }

  func getFileDataAsync() throws -> any Promise<ArrayBuffer> {
    return .async {
      return try self.getFileData()
    }
  }

  // pragma MARK: Saving Photo to File

  private func saveImage(to path: String) throws {
    guard let data = photo.fileDataRepresentation() else {
      throw RuntimeError("Failed to get file data representation of Photo!")
    }
    let url = URL(fileURLWithPath: path)
    try data.write(to: url)
  }

  func saveToFileAsync(path: String) throws -> any Promise<Void> {
    return .async(.utility) {
      try self.saveImage(to: path)
    }
  }

  func saveToTemporaryFileAsync() throws -> any Promise<String> {
    return .async(.utility) {
      // 1. Create temp path
      let fileType = try self.containerFormat.toUTType()
      let file = try URL.createTempURL(fileType: fileType)
      let path = file.path
      // 2. Save image
      try self.saveImage(to: path)
      // 3. Return path
      return path
    }
  }

  func toImage() throws -> any HybridImageSpec {
    guard let cgImage = photo.cgImageRepresentation() else {
      if isRawPhoto {
        throw RuntimeError("Failed to get Image data! Raw Photos cannot be converted to Images.")
      } else {
        throw RuntimeError("Failed to get Image data!")
      }
    }
    let uiOrientation = orientation.toUIImageOrientation(isMirrored: isMirrored)
    let uiImage = UIImage(cgImage: cgImage, scale: 1, orientation: uiOrientation)
    return try HybridUIImage(uiImage: uiImage)
  }

  func toImageAsync() throws -> any Promise<any HybridImageSpec> {
    return .async {
      return try self.toImage()
    }
  }
}
