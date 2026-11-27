///
/// HybridFrameRendererView.swift
/// VisionCamera
/// Copyright © 2025 Marc Rousavy @ Margelo
///

import AVFoundation
import UIKit
import Foundation
import NitroModules

// `@unchecked Sendable`: the view and renderer layer are only touched on the main thread.
final class HybridFrameRendererView: HybridFrameRendererViewSpec, @unchecked Sendable {
  // Fabric creates Nitro views on the main thread.
  let view: UIView = MainActor.assumeIsolated { AutoLayerResizingView() }
  var renderer: (any HybridFrameRendererSpec)? {
    didSet {
      updateRendererLayer()
    }
  }

  private func updateRendererLayer() {
    DispatchQueue.main.async {
      self.view.layer.sublayers?.removeAll()
      if let renderer = self.renderer as? any NativeFrameRenderer {
        self.view.layer.addSublayer(renderer.layer)
        renderer.layer.frame = self.view.bounds
      }
    }
  }
}
