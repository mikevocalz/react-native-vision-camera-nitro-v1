//
//  MediaSampleMetadata.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 29.10.25.
//

public import AVFoundation
public import Foundation
public import NitroModules
public import UIKit

public struct MediaSampleMetadata {
  let timestamp: CMTime
  let orientation: CameraOrientation
  let isMirrored: Bool

  init(timestamp: CMTime, orientationFromOutput output: AVCaptureOutput) throws {
    guard let connection = output.connection(with: .video) else {
      throw RuntimeError("Output \(output) does not have a video connection!")
    }
    self.init(timestamp: timestamp, orientationFromConnection: connection)
  }
  init(timestamp: CMTime, orientationFromConnection connection: AVCaptureConnection) {
    self.timestamp = timestamp
    self.orientation = connection.orientation
    self.isMirrored = connection.isVideoMirrored
  }
  init(timestamp: CMTime, orientation: CameraOrientation, isMirrored: Bool) {
    self.timestamp = timestamp
    self.orientation = orientation
    self.isMirrored = isMirrored
  }

  var uiImageOrientation: UIImage.Orientation {
    return orientation.toUIImageOrientation(isMirrored: isMirrored)
  }
}
