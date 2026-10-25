//
//  HybridTapToFocusGestureController.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 04.02.26.
//

import AVFoundation
import NitroModules
import UIKit

final class HybridTapToFocusGestureController: HybridTapToFocusGestureControllerSpec,
  NativeGestureController
{
  // Created on the calling (JS) thread, like VisionCamera 5.2.3 did.
  let gestureRecognizer = MainActor.assumeIsolatedUnchecked { UITapGestureRecognizer() }
  weak var controller: (any HybridCameraControllerSpec)? = nil

  private weak var previewView: (any HybridPreviewViewSpec)? = nil

  override init() throws {
    try super.init()
    gestureRecognizer.cancelsTouchesInView = false
    gestureRecognizer.addTarget(self, action: #selector(onTap(_:)))
  }

  @objc private func onTap(_ gestureRecognizer: UITapGestureRecognizer) {
    guard let controller, let previewView else {
      return
    }

    do {
      let viewPoint = gestureRecognizer.location(in: gestureRecognizer.view)
      let meteringPoint = try previewView.createMeteringPoint(
        viewX: viewPoint.x,
        viewY: viewPoint.y,
        size: nil)
      _ = try controller.focusTo(point: meteringPoint, options: FocusOptions(responsiveness: nil, adaptiveness: nil, modes: nil, autoResetAfter: nil))
    } catch {
      logger.error("Failed to focus! \(error)")
    }
  }

  func onAttached(to preview: any HybridPreviewViewSpec) {
    self.previewView = preview
  }
  func onDetached(from preview: any HybridPreviewViewSpec) {
    if self.previewView === preview {
      self.previewView = nil
    }
  }
}
