///
/// HybridCameraPhotoOutput.swift
/// VisionCamera
/// Copyright © 2025 Marc Rousavy @ Margelo
///

import AVFoundation
import Foundation
import NitroModules
import UIKit

final class HybridZoomGestureController: HybridZoomGestureControllerSpec, NativeGestureController {
  // Created on the calling (JS) thread, like VisionCamera 5.2.3 did.
  let gestureRecognizer = MainActor.assumeIsolatedUnchecked { UIPinchGestureRecognizer() }
  weak var controller: (any HybridCameraControllerSpec)? = nil

  private let MAX_ZOOM_FACTOR = 15.0
  private var initialZoomFactor = 1.0

  override init() throws {
    try super.init()
    gestureRecognizer.cancelsTouchesInView = false
    gestureRecognizer.addTarget(self, action: #selector(onPinch(_:)))
  }

  // UIKit delivers gesture actions on the main thread.
  @MainActor @objc private func onPinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
    guard let controller = controller as? any NativeCameraController else {
      return
    }
    let device = controller.captureDevice

    switch gestureRecognizer.state {
    case .began:
      initialZoomFactor = device.videoZoomFactor
    case .changed:
      let targetFactor = initialZoomFactor * gestureRecognizer.scale
      let minZoom = device.minAvailableVideoZoomFactor
      let maxZoom = min(device.maxAvailableVideoZoomFactor, MAX_ZOOM_FACTOR)
      let zoom = min(max(targetFactor, minZoom), maxZoom)

      controller.queue.async {
        do {
          try device.lockForConfiguration()
          device.videoZoomFactor = zoom
          device.unlockForConfiguration()
        } catch {
          logger.error("Failed to lock device for zooming! \(error)")
        }
      }
    default:
      break
    }
  }
}
