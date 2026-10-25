///
/// NativeFrameRenderer.swift
/// VisionCamera
/// Copyright © 2025 Marc Rousavy @ Margelo
///

public import AVFoundation
public import Foundation

public protocol NativeFrameRenderer: AnyObject {
  associatedtype Layer: CALayer

  /**
   * Represents the actual `CALayer`
   * that should be added to the preview view.
   */
  var layer: Layer { get }
}
