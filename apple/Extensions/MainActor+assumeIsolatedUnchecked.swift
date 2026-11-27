///
/// MainActor+assumeIsolatedUnchecked.swift
/// VisionCamera
/// Copyright © 2026 Marc Rousavy @ Margelo
///

extension MainActor {
  /// Runs `body` on the calling thread without checking that it is the main thread.
  ///
  /// VisionCamera 5.2.3 (Swift 5 mode) creates some UIKit objects, such as gesture recognizers,
  /// on the JS thread when JS calls a factory method. Swift 6 rejects that statically.
  /// This keeps the 5.2.3 behaviour instead of adding a thread hop to the factory call.
  /// `MainActor.assumeIsolated` cannot be used here because it traps off the main thread.
  /// Only use it for object construction that 5.2.3 already performed off the main thread.
  static func assumeIsolatedUnchecked<T>(_ body: @MainActor () throws -> T) rethrows -> T {
    typealias NonisolatedBody = () throws -> T
    return try withoutActuallyEscaping(body) { body in
      let nonisolatedBody = unsafeBitCast(body, to: NonisolatedBody.self)
      return try nonisolatedBody()
    }
  }
}
