///
/// NativeCameraSessionConfig.swift
/// VisionCamera
/// Copyright © 2025 Marc Rousavy @ Margelo
///

public import AVFoundation
public import Foundation

public protocol NativeCameraSessionConfig {
  var negotiatedFormat: NegotiatedFormat { get }
  var enabledConstraints: EnabledConstraints { get }
}
