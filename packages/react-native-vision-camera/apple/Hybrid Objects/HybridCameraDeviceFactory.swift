///
/// HybridCameraDeviceFactory.swift
/// VisionCamera
/// Copyright © 2025 Marc Rousavy @ Margelo
///

import AVFoundation
import Foundation
import NitroModules

final class HybridCameraDeviceFactory: HybridCameraDeviceFactorySpec {
  override init() throws {
    self.discoverySession = AVCaptureDevice.DiscoverySession(
      deviceTypes: AVCaptureDevice.DeviceType.all,
      mediaType: nil,
      position: .unspecified)
    try super.init()
  }

  let discoverySession: AVCaptureDevice.DiscoverySession
  var cameraDevices: [any HybridCameraDeviceSpec] {
    // The Hybrid init only throws from `HybridObject` base setup, which cannot fail, and a getter cannot throw.
    return discoverySession.devices.map { try! HybridCameraDevice(device: $0) }
  }

  var supportedMultiCamDeviceCombinations: [[any HybridCameraDeviceSpec]] {
    return discoverySession.supportedMultiCamDeviceSets.map { devices in
      return devices.map { try! HybridCameraDevice(device: $0) }
    }
  }

  var userPreferredCamera: (any HybridCameraDeviceSpec)? {
    get {
      guard #available(iOS 17.0, *) else {
        return nil
      }
      guard let device = AVCaptureDevice.userPreferredCamera else {
        return nil
      }
      return try! HybridCameraDevice(device: device)
    }
    set {
      guard #available(iOS 17.0, *) else {
        return
      }
      guard let hybridDevice = newValue as? any NativeCameraDevice else {
        return
      }
      AVCaptureDevice.userPreferredCamera = hybridDevice.device
    }
  }

  func addOnCameraDevicesChangedListener(listener: any Callback<[any HybridCameraDeviceSpec], Void>)
    -> ListenerSubscription
  {
    // 1. Attach a listener using KVO
    nonisolated(unsafe) let observation = discoverySession.observe(\.devices) { _, change in
      guard let newDevices = change.newValue else { return }
      logger.info("Devices changed! \(change.oldValue?.count ?? 0) -> \(newDevices.count)")
      do {
        let devices = try newDevices.map { try HybridCameraDevice(device: $0) }
        listener(devices)
      } catch {
        logger.error("Failed to wrap changed devices: \(error)")
      }
    }

    // 2. Return a remove function that removes the listener via KVO
    // NSKeyValueObservation.invalidate() is thread-safe.
    return ListenerSubscription(remove: .native {
      observation.invalidate()
    })
  }

  func getCameraForId(id: String) throws -> (any HybridCameraDeviceSpec)? {
    guard let device = AVCaptureDevice(uniqueID: id) else {
      return nil
    }
    return try HybridCameraDevice(device: device)
  }

  func getDefaultCamera(position: TargetCameraPosition) throws -> (any HybridCameraDeviceSpec)? {
    guard let device = AVCaptureDevice.default(for: position) else {
      return nil
    }
    return try HybridCameraDevice(device: device)
  }

  func getSupportedExtensions(camera: any HybridCameraDeviceSpec) throws -> any Promise<
    [any HybridCameraExtensionSpec]
  > {
    // There are no Camera Extensions on iOS.
    return .resolved(with: [])
  }
}
