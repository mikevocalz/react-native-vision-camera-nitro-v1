///
/// HybridResizer.hpp
/// VisionCamera
/// Copyright © 2026 Marc Rousavy @ Margelo
///

#pragma once

#include <VisionCameraResizer/HybridFrameSpecCxx+VisionCamera.hpp>
#include <VisionCameraResizer/HybridGPUFrameSpecCxx.hpp>
#include <VisionCameraResizer/HybridResizerSpec.hpp>
#include <VisionCameraResizer/ResizerOptions.hpp>
#include "vulkan/VulkanResizerPipeline.hpp"

#include <memory>

namespace margelo::nitro::camera::resizer {

/**
 * An implementation of `HybridResizerSpec` that uses Vulkan compute kernels for GPU accelerated resizing and output
 * layout conversion.
 */
class HybridResizer final : public HybridResizerSpec {
public:
  HybridResizer(const ResizerOptions& options);
  ~HybridResizer() override = default;

  HybridGPUFrameSpecCxx resize(const adapters::VisionCamera::HybridFrameSpecCxx& frame) override;
  void dispose() override;
  size_t getExternalMemorySize() noexcept override;

private:
  std::unique_ptr<vulkan::VulkanResizerPipeline> _pipeline;
};

} // namespace margelo::nitro::camera::resizer
