///
/// NativeThreadDispatcher.hpp
/// VisionCamera
/// Copyright © 2025 Marc Rousavy @ Margelo
///

#pragma once

#include "NativeThreadAsyncQueue.hpp"
#include <NitroModules/Callback.hpp>
#include <NitroModules/Dispatcher.hpp>
#include <functional>
#include <memory>
#include <stdexcept>
#include <utility>

namespace margelo::nitro::camera::worklets {

/**
 * An implementation of `nitro::Dispatcher` that uses a `NativeThread` to run its jobs.
 *
 * A `NativeThread` may run on a pooled OS Thread (e.g. a serial `DispatchQueue`), so
 * `isOnDispatcher()` tracks whether the caller is inside a job this Dispatcher started.
 */
class NativeThreadDispatcher : public nitro::Dispatcher, public std::enable_shared_from_this<NativeThreadDispatcher> {
public:
  explicit NativeThreadDispatcher(NativeThread thread) : _thread(std::move(thread)) {}

  void runSync(std::function<void()>&&) override {
    throw std::runtime_error("runSync(...) is not implemented for NativeThreadDispatcher!");
  }
  void runAsync(std::function<void()>&& function) override {
    std::weak_ptr<NativeThreadDispatcher> weakSelf = weak_from_this();
    _thread.runOnThread(Callback<void()>::make([weakSelf, function = std::move(function)]() {
      auto self = weakSelf.lock();
      const NativeThreadDispatcher* previous = currentDispatcher();
      currentDispatcher() = self.get();
      try {
        function();
      } catch (...) {
        currentDispatcher() = previous;
        throw;
      }
      currentDispatcher() = previous;
    }));
  }
  bool isOnDispatcher() override {
    return currentDispatcher() == this;
  }

private:
  static const NativeThreadDispatcher*& currentDispatcher() {
    static thread_local const NativeThreadDispatcher* dispatcher = nullptr;
    return dispatcher;
  }

private:
  NativeThread _thread;
};

} // namespace margelo::nitro::camera::worklets
