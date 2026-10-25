//
//  NativeCameraController.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 04.02.26.
//

public import AVFoundation
public import Foundation

public protocol NativeCameraController: AnyObject {
  var queue: DispatchQueue { get }
  var captureDevice: AVCaptureDevice { get }
}
