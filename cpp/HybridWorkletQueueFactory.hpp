///
/// HybridWorkletQueueFactory.hpp
/// VisionCamera
/// Copyright © 2025 Marc Rousavy @ Margelo
///

#pragma once

#include "JSIConverter+AsyncQueue.hpp"
#include <NitroModules/HybridClass.hpp>
#include <VisionCameraWorklets/HybridNativeThreadSpecCxx+VisionCamera.hpp>
#include <VisionCameraWorklets/HybridWorkletQueueFactorySpec.hpp>
#include <jsi/jsi.h>
#include <memory>

namespace margelo::nitro::camera::worklets {

class HybridWorkletQueueFactory : public HybridWorkletQueueFactorySpec {
public:
  /**
   * Adds the raw `installDispatcher(thread)` method on top of the generated
   * `WorkletQueueFactory` class. Nitro V1 builds prototypes from a `HybridClass`.
   */
  struct Class {
    using Base = HybridWorkletQueueFactorySpec::Class;
    static constexpr const char* name = "HybridWorkletQueueFactory";
    static const std::shared_ptr<const HybridClass>& get();
  };

public:
  HybridWorkletQueueFactory() = default;

public:
  std::shared_ptr<::worklets::AsyncQueue> wrapThreadInQueue(const adapters::VisionCamera::HybridNativeThreadSpecCxx& thread) override;
  double getCurrentThreadMarker() override;

  jsi::Value installDispatcher(jsi::Runtime& runtime, const jsi::Value&, const jsi::Value* args, size_t count);

protected:
  const std::shared_ptr<const HybridClass>& getHybridClass() override {
    return Class::get();
  }
};

} // namespace margelo::nitro::camera::worklets
