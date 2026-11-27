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
  private let onTapListeners = ListenerRegistry<any Callback<any HybridMeteringPointSpec, Void>>()
  private let onFocusCompletedListeners = ListenerRegistry<
    any Callback<any HybridMeteringPointSpec, Void>
  >()

  override init() throws {
    try super.init()
    // Configured on the calling (JS) thread, like VisionCamera 5.2.3 did.
    nonisolated(unsafe) let target = self
    let gestureRecognizer = self.gestureRecognizer
    MainActor.assumeIsolatedUnchecked {
      gestureRecognizer.cancelsTouchesInView = false
      gestureRecognizer.addTarget(target, action: #selector(onTap(_:)))
    }
  }

  // UIKit delivers gesture actions on the main thread.
  @MainActor @objc private func onTap(_ gestureRecognizer: UITapGestureRecognizer) {
    guard let controller, let previewView else {
      return
    }

    do {
      let viewPoint = gestureRecognizer.location(in: gestureRecognizer.view)
      let meteringPoint = try previewView.createMeteringPoint(
        viewX: viewPoint.x,
        viewY: viewPoint.y,
        size: nil)
      onTapListeners.snapshot().forEach { $0(meteringPoint) }

      let focusPromise = try controller.focusTo(
        point: meteringPoint,
        options: FocusOptions(responsiveness: nil, adaptiveness: nil, modes: nil, autoResetAfter: nil))
      let onFocusCompletedListeners = self.onFocusCompletedListeners
      // The MeteringPoint is immutable after creation, and its listeners are JS callbacks
      // that dispatch to their own thread, so handing it to the Promise's thread is safe.
      nonisolated(unsafe) let focusedPoint = meteringPoint
      focusPromise.addOnResolvedListener { _ in
        onFocusCompletedListeners.snapshot().forEach { $0(focusedPoint) }
      }
      focusPromise.addOnRejectedListener { error in
        logger.error("Failed to focus! \(error)")
      }
    } catch {
      logger.error("Failed to focus! \(error)")
    }
  }

  func addOnTapListener(onTap: any Callback<any HybridMeteringPointSpec, Void>) throws
    -> ListenerSubscription
  {
    return onTapListeners.add(onTap)
  }

  func addOnFocusCompletedListener(
    onFocusCompleted: any Callback<any HybridMeteringPointSpec, Void>
  ) throws -> ListenerSubscription {
    return onFocusCompletedListeners.add(onFocusCompleted)
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
