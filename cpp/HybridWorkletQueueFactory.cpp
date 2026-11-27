///
/// HybridWorkletQueueFactory.cpp
/// VisionCamera
/// Copyright © 2025 Marc Rousavy @ Margelo
///

#include "HybridWorkletQueueFactory.hpp"

#include "NativeThreadAsyncQueue.hpp"
#include "NativeThreadDispatcher.hpp"
#include <NitroModules/Dispatcher.hpp>
#include <atomic>
#include <stdexcept>

namespace margelo::nitro::camera::worklets {

const std::shared_ptr<const HybridClass>& HybridWorkletQueueFactory::Class::get() {
  static const auto hybridClass = HybridClass::create<Class>([](HybridClass& clazz) {
    clazz.registerRawHybridMethod("installDispatcher", 1, &HybridWorkletQueueFactory::installDispatcher);
  });
  return hybridClass;
}

std::shared_ptr<::worklets::AsyncQueue> HybridWorkletQueueFactory::wrapThreadInQueue(const adapters::VisionCamera::HybridNativeThreadSpecCxx& thread) {
  return std::make_shared<NativeThreadAsyncQueue>(thread);
}

double HybridWorkletQueueFactory::getCurrentThreadMarker() {
  static std::atomic_size_t threadCounter{1};
  static thread_local size_t thisThreadId{0};
  if (thisThreadId == 0) {
    thisThreadId = threadCounter.fetch_add(1);
  }
  return static_cast<double>(thisThreadId);
}

jsi::Value HybridWorkletQueueFactory::installDispatcher(jsi::Runtime& runtime, const jsi::Value&, const jsi::Value* args, size_t count) {
  if (count != 1)
    throw std::runtime_error("installDispatcher(..) must be called with exactly 1 argument!");
  auto thread = JSIConverter<adapters::VisionCamera::HybridNativeThreadSpecCxx>::fromJSI(runtime, args[0]);

  auto dispatcher = std::make_shared<NativeThreadDispatcher>(std::move(thread));
  Dispatcher::installRuntimeGlobalDispatcher(runtime, dispatcher);

  return jsi::Value::undefined();
}

} // namespace margelo::nitro::camera::worklets
