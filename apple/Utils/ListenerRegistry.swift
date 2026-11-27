///
/// ListenerRegistry.swift
/// VisionCamera
/// Copyright © 2025 Marc Rousavy @ Margelo
///

import Foundation
import NitroModules

/// Holds JS listeners that are added and removed on the JS thread
/// and emitted from another thread (e.g. UIKit's main thread).
///
/// The lock only guards the dictionary. Listeners are always called
/// from a snapshot, after the lock has been released.
final class ListenerRegistry<Listener>: @unchecked Sendable {
  private let lock = NSLock()
  private var listeners: [UUID: Listener] = [:]

  func add(_ listener: Listener) -> ListenerSubscription {
    let id = UUID()
    lock.lock()
    listeners[id] = listener
    lock.unlock()
    return ListenerSubscription(remove: .native { [weak self] in
      self?.remove(id)
    })
  }

  func snapshot() -> [Listener] {
    lock.lock()
    defer { lock.unlock() }
    return Array(listeners.values)
  }

  private func remove(_ id: UUID) {
    lock.lock()
    listeners.removeValue(forKey: id)
    lock.unlock()
  }
}
