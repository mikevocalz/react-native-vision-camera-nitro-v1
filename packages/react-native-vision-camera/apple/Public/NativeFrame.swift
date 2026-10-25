//
//  NativeFrame.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 05.11.25.
//

public import AVFoundation
public import Foundation

public protocol NativeFrame: AnyObject {
  var sampleBuffer: CMSampleBuffer? { get }
  var metadata: MediaSampleMetadata { get }
}
