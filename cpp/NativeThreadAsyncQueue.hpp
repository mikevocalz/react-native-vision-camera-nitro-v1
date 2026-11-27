///
/// NativeThreadAsyncQueue.hpp
/// VisionCamera
/// Copyright © 2025 Marc Rousavy @ Margelo
///

#pragma once

#include "JSIConverter+AsyncQueue.hpp"
#include <NitroModules/Callback.hpp>
#include <VisionCameraWorklets/HybridNativeThreadSpecCxx+VisionCamera.hpp>
#include <functional>
#include <utility>

namespace margelo::nitro::camera::worklets {

using NativeThread = adapters::VisionCamera::HybridNativeThreadSpecCxx;

/**
 * An implementation of `worklets::AsyncQueue` that uses a `NativeThread` to run its jobs.
 *
 * The `NativeThread` is implemented in Swift (`DispatchQueue`) or Kotlin (`Executor`) by
 * VisionCamera. Nitrogen's C++ adapter (`HybridNativeThreadSpecCxx`) lets C++ call it.
 */
class NativeThreadAsyncQueue : public ::worklets::AsyncQueue {
public:
  explicit NativeThreadAsyncQueue(NativeThread thread) : _thread(std::move(thread)) {}

  void push(std::function<void()>&& job) override {
    _thread.runOnThread(Callback<void()>::make(std::move(job)));
  }

private:
  NativeThread _thread;
};

} // namespace margelo::nitro::camera::worklets
