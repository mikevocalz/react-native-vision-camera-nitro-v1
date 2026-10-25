///
/// HybridNativeThread.swift
/// VisionCamera
/// Copyright © 2025 Marc Rousavy @ Margelo
///

import Foundation
import NitroModules

final class HybridNativeThread: HybridNativeThreadSpec {
  let queue: DispatchQueue

  init(queue: DispatchQueue) throws {
    self.queue = queue
    try super.init()
  }

  var id: String {
    return queue.label
  }

  func runOnThread(task: any Callback<(), Void>) throws {
    queue.async {
      task()
    }
  }
}
