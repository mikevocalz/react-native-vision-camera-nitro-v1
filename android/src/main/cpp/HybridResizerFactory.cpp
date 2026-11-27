///
/// HybridResizerFactory.cpp
/// VisionCamera
/// Copyright © 2026 Marc Rousavy @ Margelo
///

#include "HybridResizerFactory.hpp"

#include "vulkan/VulkanResizerPipeline.hpp"

namespace margelo::nitro::camera::resizer {

HybridResizerFactory::HybridResizerFactory() = default;

bool HybridResizerFactory::isAvailable() {
  return vulkan::VulkanResizerPipeline::isSupported();
}

Promise<HybridResizerSpecCxx> HybridResizerFactory::createResizer(const ResizerOptions& options) {
  return Promise<HybridResizerSpecCxx>::async([=]() {
    // Create `HybridResizer` on a separate C++ Thread (pooled),
    // so that the Vulkan setup doesn't block the main JS Thread.
    return HybridResizerSpecCxx::fromNative(std::make_shared<HybridResizer>(options));
  });
}

} // namespace margelo::nitro::camera::resizer
