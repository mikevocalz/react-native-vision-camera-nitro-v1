///
/// VisionCamera.swift
/// VisionCamera
/// Copyright © 2025 Marc Rousavy @ Margelo
///

import AVFoundation
import Foundation
import NitroModules

// `@unchecked Sendable`: V1 Promise closures are `@Sendable`; it has no stored state.
final class VisionCamera: HybridCameraFactorySpec, @unchecked Sendable {
  var cameraPermissionStatus: PermissionStatus {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    return PermissionStatus(avStatus: status)
  }

  var microphonePermissionStatus: PermissionStatus {
    let status = AVCaptureDevice.authorizationStatus(for: .audio)
    return PermissionStatus(avStatus: status)
  }

  func requestCameraPermission() -> any Promise<Bool> {
    return .async {
      guard Bundle.main.infoDictionary?["NSCameraUsageDescription"] != nil else {
        throw RuntimeError("Cannot request Camera Permission - Your Info.plist does not contain a `NSCameraUsageDescription` key!"
        )
      }
      return await AVCaptureDevice.requestAccess(for: .video)
    }
  }

  func requestMicrophonePermission() -> any Promise<Bool> {
    return .async {
      guard Bundle.main.infoDictionary?["NSMicrophoneUsageDescription"] != nil else {
        throw RuntimeError("Cannot request Microphone Permission - Your Info.plist does not contain a `NSMicrophoneUsageDescription` key!"
        )
      }
      return await AVCaptureDevice.requestAccess(for: .audio)
    }
  }

  var supportsMultiCamSessions: Bool {
    return AVCaptureMultiCamSession.isMultiCamSupported
  }

  func createCameraSession(enableMultiCam: Bool) -> any Promise<any HybridCameraSessionSpec> {
    return .async {
      if enableMultiCam {
        guard self.supportsMultiCamSessions else {
          throw RuntimeError("Failed to create CameraSession - this device does not support multi-cam session! (See .supportsMultiCamSession)"
          )
        }
      }
      return try HybridCameraSession(enableMultiCam: enableMultiCam)
    }
  }

  func createDeviceFactory() -> any Promise<any HybridCameraDeviceFactorySpec> {
    return .async {
      return try HybridCameraDeviceFactory()
    }
  }

  func createPhotoOutput(options: PhotoOutputOptions) throws -> any HybridCameraPhotoOutputSpec {
    return try HybridCameraPhotoOutput(options: options)
  }

  func createVideoOutput(options: VideoOutputOptions) throws -> any HybridCameraVideoOutputSpec {
    if options.enablePersistentRecorder == true {
      // On iOS, the `AVCaptureMovieFileOutput` does not allow flipping the Camera while
      // recording, which is a feature we call "enablePersistentRecorder".
      // So if the user plans on using persistent recordings, we need to create a custom
      // video output that uses `AVCaptureVideoDataOutput` + `AVAssetWriter` instead.
      return try HybridCameraVideoFrameOutput(options: options)
    } else {
      return try HybridCameraVideoOutput(options: options)
    }
  }

  func createFrameOutput(options: FrameOutputOptions) throws -> any HybridCameraFrameOutputSpec {
    return try HybridCameraFrameOutput(options: options)
  }

  func createDepthFrameOutput(options: DepthFrameOutputOptions)
    throws -> any HybridCameraDepthFrameOutputSpec
  {
    return try HybridCameraDepthFrameOutput(options: options)
  }

  func createObjectOutput(options: ObjectOutputOptions) throws -> any HybridCameraObjectOutputSpec {
    return try HybridCameraObjectOutput(options: options)
  }

  func createPreviewOutput() throws -> any HybridCameraPreviewOutputSpec {
    return try HybridCameraPreviewOutput()
  }

  func createOutputSynchronizer(outputs: [any HybridCameraOutputSpec]) throws
    -> any HybridCameraOutputSynchronizerSpec
  {
    return try HybridCameraOutputSynchronizer(outputs: outputs)
  }

  func createZoomGestureController() throws -> any HybridZoomGestureControllerSpec {
    return try HybridZoomGestureController()
  }

  func createTapToFocusGestureController() throws -> any HybridTapToFocusGestureControllerSpec {
    return try HybridTapToFocusGestureController()
  }

  func createOrientationManager(orientationSource: OrientationSource)
    throws -> any HybridOrientationManagerSpec
  {
    switch orientationSource {
    case .interface:
      return try HybridInterfaceOrientationManager()
    case .device:
      return try HybridDeviceOrientationManager()
    }
  }

  func createFrameRenderer() throws -> any HybridFrameRendererSpec {
    return try HybridFrameRenderer()
  }

  func createNormalizedMeteringPoint(x: Double, y: Double, size: Double?)
    throws -> any HybridMeteringPointSpec
  {
    return try HybridMeteringPoint(normalizedX: x, normalizedY: y, normalizedSize: size ?? 0.1)
  }

  func resolveConstraints(
    device: any HybridCameraDeviceSpec,
    outputConfigurations: [CameraOutputConfiguration],
    constraints: [Constraint],
    requiresMultiCam: Bool?
  ) -> any Promise<any HybridCameraSessionConfigSpec> {
    // JS handed these over; only the background closure reads them from here on.
    nonisolated(unsafe) let device = device
    nonisolated(unsafe) let outputConfigurations = outputConfigurations
    nonisolated(unsafe) let constraints = constraints
    return .parallel {
      let outputs = outputConfigurations.map { $0.output }
      let resolvedConstraints = try ConstraintResolver.resolveConstraints(
        for: device,
        constraints: constraints,
        outputs: outputs,
        isMultiCam: requiresMultiCam == true)
      return try HybridCameraSessionConfig(
        negotiatedFormat: resolvedConstraints.negotiatedFormat,
        enabledConstraints: resolvedConstraints.enabledConstraints)
    }
  }
}
