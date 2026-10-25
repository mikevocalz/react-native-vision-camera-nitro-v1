//
//  NativeDepth.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 05.11.25.
//

public import AVFoundation
public import Foundation

public protocol NativeDepth: AnyObject {
  var depthData: AVDepthData? { get }
  var metadata: MediaSampleMetadata { get }
}
